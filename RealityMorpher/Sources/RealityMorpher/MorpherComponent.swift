import Foundation
import RealityKit
import CoreGraphics
import RealityMorpherKernels
import Accelerate

public struct MorpherComponent: Component {
	enum Error: String, Swift.Error {
		case missingBaseMesh
		case targetsNotTopologicallyIdentical
		case tooMuchGeometry
		case invalidNumberOfTargets
		case couldNotCreateImage
		case positionsCountNotEqualToNormalsCount
	}
	
	public enum Option: String {
		case debugNormals
	}
	
	public fileprivate(set) var weights: MorpherWeights = .zero
	/// We need to keep a reference to the texture resources we create, otherwise the custom textures get nilled when they update
	let textureResources: [TextureResource]
	fileprivate(set) var weightsVertexCount: SIMD4<Float>
	fileprivate var animator: MorpherAnimating?
	private static let maxTextureWidth = 8192
	private static let maxTargetCount = MorpherConstant.maxTargetCount.rawValue
	
	public init(entity: HasModel, targets: [ModelComponent], options: Set<Option> = []) throws {
		guard var model = entity.model else { throw Error.missingBaseMesh }
		guard 1...Self.maxTargetCount ~= targets.count else { throw Error.invalidNumberOfTargets }
		guard Self.allTargets(targets, areTopologicallyIdenticalToModel: model) else {
			throw Error.targetsNotTopologicallyIdentical
		}
		let vertexCount = model.positionCounts.flatMap { $0 }.reduce(0, +)
		let maxElements = Self.maxTextureWidth * Self.maxTextureWidth
		guard vertexCount * targets.count * 2 <= maxElements else {
			throw Error.tooMuchGeometry
		}
		weightsVertexCount = .init(.zero, Float(vertexCount))
		var texResources: [TextureResource] = []

		// Because we have no "submesh index" or "part index" within the geometry modifier, each part of the mesh needs to have its own material, where in the original model they might have shared materials
		var updatedContents = MeshResource.Contents()
		updatedContents.instances = model.mesh.contents.instances
		var updatedMaterials: [CustomMaterial] = []
		
		updatedContents.models = try MeshModelCollection(model.mesh.contents.models.enumerated().map { (submodelId, submodel) in
			try MeshResource.Model(id: submodel.id, parts: submodel.parts.enumerated().map { (partId, part) in
				let material = model.materials[part.materialIndex]
				
				var updatedMaterial = if options.contains(.debugNormals) {
					try CustomMaterial(surfaceShader: MorpherEnvironment.shared.debugShader, geometryModifier: MorpherEnvironment.shared.morphGeometryModifier, lightingModel: .clearcoat)
				} else {
					try CustomMaterial(from: material, geometryModifier: MorpherEnvironment.shared.morphGeometryModifier)
				}
				let targetParts: [MeshResource.Part] = targets.map {
					$0.mesh.contents.models.map { $0 }[submodelId]
						.parts.map { $0 }[partId]
				}
				let textureResource = try Self.createTextureForPart(part, targetParts: targetParts, vertCount: vertexCount)
				texResources.append(textureResource)
				updatedMaterial.custom.texture = CustomMaterial.Texture(textureResource)
				updatedMaterial.custom.value = [0, 0, 0, Float(part.positions.count)]
				let materialIndex = updatedMaterials.count
				updatedMaterials.append(updatedMaterial)
				var newPart = part
				newPart.materialIndex = materialIndex
				return newPart
			})
		})
		self.textureResources = texResources
		let updatedMesh = try MeshResource.generate(from: updatedContents)
		model.materials = updatedMaterials
		model.mesh = updatedMesh
		entity.components.set(model)
	}
	
	/// Create texture from part positions & normals
	static private func createTextureForPart(_ base: MeshResource.Part, targetParts: [MeshResource.Part], vertCount: Int) throws -> TextureResource {
		let paddingCount = maxTargetCount - targetParts.count
		let padding: [Float] = Array(repeating: .zero, count: vertCount * 3 * paddingCount)
		let positions: [Float] = targetParts.flatMap(\.positions.flattenedElements)
		let basePositions: [Float] = Array(repeating: base.positions.flattenedElements, count: targetParts.count).flatMap { $0 }
		let offsets: [Float] = vDSP.subtract(positions, basePositions)
		let normals: [Float] = targetParts.flatMap {
			$0.normals?.flattenedElements ?? []
		}
		guard positions.count == normals.count else { throw Error.positionsCountNotEqualToNormalsCount }
		let elements = (offsets + padding + normals + padding).map { Float16($0) }
		let pixelcount = elements.count / 3
		let width = min(vertCount, maxTextureWidth)
		let (quotient, remainder) = pixelcount.quotientAndRemainder(dividingBy: width)
		let height = remainder == 0 ? quotient : quotient + 1
		let finalPadding = Array(repeating: Float16.zero, count: (width - remainder) * 3)
		let elementsWithPadding = elements + finalPadding
		let data = elementsWithPadding.withUnsafeBytes {
			Data($0)
		} as CFData
		let bitmapInfo: CGBitmapInfo = [.byteOrder16Little, .floatComponents]
		let bitsPerComponent = 16
		let bitsPerPixel = bitsPerComponent * 3
		let bytesPerPixel = bitsPerPixel / 8
		guard let provider = CGDataProvider(data: data),
			  let image = CGImage(width: width, height: height, bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: width * bytesPerPixel, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
		else {
			throw Error.couldNotCreateImage
		}
		return try TextureResource.generate(from: image, options: TextureResource.CreateOptions(semantic: .raw, mipmapsMode: .none))
	}
	
	private static func allTargets(_ targets: [ModelComponent], areTopologicallyIdenticalToModel model: ModelComponent) -> Bool {
		let modelCounts = model.positionCounts
		let allPositionCounts = targets.map(\.positionCounts)
		return allPositionCounts.allSatisfy { counts in
			counts == modelCounts
		}
	}
}

// MARK: - Animation

extension MorpherComponent {
	public mutating func setTargetWeights(_ target: MorpherWeights, animation: MorpherAnimation = .immediate) {
		weights = target
		if #available(iOS 17.0, *) {
			animator = TimelineAnimator(origin: MorpherWeights(weightsVertexCount.xyz), target: target, animation: animation)
		} else {
			animator = LinearAnimator(origin: MorpherWeights(weightsVertexCount.xyz), target: target, animation: animation)
		}
	}
	
	func updated(deltaTime: TimeInterval) -> MorpherComponent? {
		var output = self
		guard let event = output.animator?.update(with: deltaTime), event.status == .running else { return nil }
		output.weightsVertexCount.xyz = event.weights.values
		return output
	}
}

private extension ModelComponent {
	/// A nested array of the vertex counts for each part within each submodel
	var positionCounts: [[Int]] {
		mesh.contents.models.map { model in
			model.parts.map { part in
				part.positions.count
			}
		}
	}
}

private extension MeshBuffer where Element == SIMD3<Float> {
	var flattenedElements: [Float] {
		elements.flatMap { [$0.x, $0.y, $0.z] }
	}
}

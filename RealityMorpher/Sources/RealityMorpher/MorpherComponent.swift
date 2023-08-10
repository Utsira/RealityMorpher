import Foundation
import RealityKit
import CoreGraphics
import RealityMorpherKernels

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
	
	public var weights: SIMD3<Float> = .zero
	/// We need to keep a reference to the texture resources we create, otherwise the custom textures get nilled when they update
	let textureResources: [TextureResource]
	private static let maxTextureWidth = 8192
	private static let maxTargetCount = MorpherConstant.maxTargetCount.rawValue
	
	private(set) var weightsVertexCount: SIMD4<Float>
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
				let textureResource = try Self.createTextureForParts(targetParts, vertCount: vertexCount)
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
	static private func createTextureForParts(_ parts: [MeshResource.Part], vertCount: Int) throws -> TextureResource {
		let paddingCount = maxTargetCount - parts.count
		let padding: [SIMD3<Float>] = Array(repeating: .zero, count: vertCount * paddingCount)
		let positions = parts.flatMap(\.positions.elements)
		let normals = parts.flatMap { $0.normals?.elements ?? [] }
		guard positions.count == normals.count else { throw Error.positionsCountNotEqualToNormalsCount }
		let elements = (positions + padding + normals + padding)
			.map {
				(Float16($0.x), Float16($0.y), Float16($0.z) )
			}
		let width = min(vertCount, maxTextureWidth)
		let (quotient, remainder) = elements.count.quotientAndRemainder(dividingBy: width)
		let height = remainder == 0 ? quotient : quotient + 1
		let finalPadding = Array(repeating: (Float16.zero, Float16.zero, Float16.zero), count: (width * height) - elements.count)
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

	func updated() -> MorpherComponent? {
		guard weightsVertexCount.xyz != weights else { return nil }
		var update = self
		let halfDistanceToTarget = (weights - weightsVertexCount.xyz) * 0.2
		if length_squared(halfDistanceToTarget) < 0.00001 {
			update.weightsVertexCount.xyz = weights
		} else {
			update.weightsVertexCount.xyz += halfDistanceToTarget
		}
		return update
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

extension SIMD4 {
	var xyz: SIMD3<Scalar> {
		get {
			SIMD3(x: x, y: y, z: z)
		}
		set {
			self = SIMD4(newValue, w)
		}
	}
}

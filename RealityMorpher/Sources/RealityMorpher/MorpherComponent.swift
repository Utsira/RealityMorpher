import Foundation
import RealityKit
import CoreGraphics
import RealityMorpherKernels
import Accelerate

/// Add this component to a `ModelEntity` to enable morph target (AKA shape key or blend shape) animations.
public struct MorpherComponent: Component {
	
	/// Errors thrown from ``MorpherComponent/init(entity:targets:options:)``
	public enum Error: String, Swift.Error {
		/// The `entity` passed to ``MorpherComponent/init(entity:targets:options:)`` does not have a `ModelComponent`
		case missingBaseMesh
		
		/// The `targets` passed to ``MorpherComponent/init(entity:targets:options:)`` do not have the same number of vertices as the model on the base `entity`, arranged in the same configuration of submodels and parts.
		case targetsNotTopologicallyIdentical
		
		/// The total number of vertices summed from all the `targets` passed to ``MorpherComponent/init(entity:targets:options:)`` exceeds the maximum of  33,554,432
		case tooMuchGeometry
		
		/// The array of `targets` passed to ``MorpherComponent/init(entity:targets:options:)`` must contain 1, 2, or 3 elements
		case invalidNumberOfTargets
		
		/// Morpher texture creation failed for some reason. Please check the logs for CGImage related failure and raise an issue on the repository
		case couldNotCreateImage
		
		/// The number of normals is different from the number of vertices. All vertices of the model should contain normals.
		case positionsCountNotEqualToNormalsCount
	}
	
	public enum Option: String {
		/// Display normals as vertex colors
		case debugNormals
	}
	
	/// The weights for each of the targets passed to ``init(entity:targets:options:)``.
	///
	/// Use ``setTargetWeights(_:animation:)`` to update thse with an animation
	public fileprivate(set) var weights: MorpherWeights = .zero
	
	/// We need to keep a reference to the texture resources we create, otherwise the custom textures get nilled when they update
	let textureResources: [TextureResource]
	
	private(set) var weightsVertexCount: SIMD4<Float>
	private var animator: MorpherAnimating?
	private static let maxTextureWidth = 8192
	private static let maxTargetCount = MorpherConstant.maxTargetCount.rawValue
	
	/// Initialises a new MorpherComponent for animating deforms to a model's geometry.
	///
	/// - Parameters:
	///   - entity: the `ModelEntity` that this component will be added to. This entity's materials will all be converted into `CustomMaterial`s in order to deform the geometry
	///   - targets: an array of target geometries that can be morphed to. There must be between 1 and 3 geometries in this array. Each geometry must be topologically identical to the base entity's model (in other words have the same number of submodels, composed of the same number of parts, each of which must have the same number of vertices)
	///   - options: a set of ``Option`` flags that can be passed, Defaults to an empty set.
	///
	/// - Throws: See ``Error`` for errors thrown from this initialiser
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
	
	// MARK: - Animation
	
	/// Updates the ``weights`` for the morph `targets` passed to ``init(entity:targets:options:)``
	/// - Parameters:
	///   - targetWeights: the new ``weights`` to animate to for each of the targets.
	///   - animation: the animation with which the update to the target ``weights`` will be applied
	public mutating func setTargetWeights(_ targetWeights: MorpherWeights, animation: MorpherAnimation = .immediate) {
		weights = targetWeights
		if #available(iOS 17.0, *) {
			animator = TimelineAnimator(origin: MorpherWeights(weightsVertexCount.xyz), target: targetWeights, animation: animation)
		} else {
			animator = LinearAnimator(origin: MorpherWeights(weightsVertexCount.xyz), target: targetWeights, animation: animation)
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

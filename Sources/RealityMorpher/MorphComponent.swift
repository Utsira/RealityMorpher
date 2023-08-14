import Foundation
import RealityKit
import CoreGraphics
import RealityMorpherKernels
import Accelerate
import SwiftUI

/// Add this component to a `ModelEntity` to enable morph target (AKA shape key or blend shape) animations.
public struct MorphComponent: Component {
	/// Debug options
	public enum Option: String {
		/// Display normals as vertex colors
		case debugNormals
	}
	
	/// The weights for each of the targets, not accounting for any animations that are in flight.
	///
	/// When you set a desired weight using ``setTargetWeights(_:animation:)``, this ``weights`` parameter will immediately reflect that change, regardless of what animation duration has been set
	public private(set) var weights: MorphWeights
	
	/// We need to keep a reference to the texture resources we create, otherwise the custom textures get nilled when they update
	let textureResources: [TextureResource]
	
	private(set) var currentWeights: SIMD4<Float>
	private var animator: MorphAnimating?
	private static let maxTextureWidth = 8192
	
	/// Initialises a new MorphComponent for animating deforms to a model's geometry.
	///
	/// - Parameters:
	///   - entity: the `ModelEntity` that this component will be added to. This entity's materials will all be converted into `CustomMaterial`s in order to deform the geometry
	///   - targets: an array of target geometries that can be morphed to. There must be between 1 and 4 geometries in this array. Each geometry must be topologically identical to the base entity's model (in other words have the same number of submodels, composed of the same number of parts, each of which must have the same number of vertices)
	///   - weights: a collection of weights describing the extent to which each target in the `targets` parameter should be applied. Typically these are in the range 0 to 1, 0 indicating the target is not applied at all, 1 indicating it is fully applied. Each element corresponds to the element at the same index in the `targets` property. Defaults to zero.
	///   - options: a set of ``Option`` flags that can be passed, Defaults to an empty set.
	///
	/// - Throws: See ``Error`` for errors thrown from this initialiser
	public init(entity: HasModel, targets: [ModelComponent], weights: MorphWeights = .zero, options: Set<Option> = []) throws {
		guard var model = entity.model else { throw Error.missingBaseMesh }
		guard 1...MorphEnvironment.maxTargetCount ~= targets.count else { throw Error.invalidNumberOfTargets }
		guard Self.allTargets(targets, areTopologicallyIdenticalToModel: model) else {
			throw Error.targetsNotTopologicallyIdentical
		}
		let vertexCount = model.positionCounts.flatMap { $0 }.reduce(0, +)
		let maxElements = Self.maxTextureWidth * Self.maxTextureWidth
		guard vertexCount * targets.count * 2 <= maxElements else {
			throw Error.tooMuchGeometry
		}
		self.weights = weights
		currentWeights = weights.values
		var texResources: [TextureResource] = []

		// Because we have no "submesh index" or "part index" within the geometry modifier, each part of the mesh needs to have its own material, where in the original model they might have shared materials
		var updatedContents = MeshResource.Contents()
		updatedContents.instances = model.mesh.contents.instances
		var updatedMaterials: [CustomMaterial] = []
		let geometryModifier = MorphEnvironment.shared.morphGeometryModifiers[targets.count - 1]
		
		updatedContents.models = try MeshModelCollection(model.mesh.contents.models.enumerated().map { (submodelId, submodel) in
			try MeshResource.Model(id: submodel.id, parts: submodel.parts.enumerated().map { (partId, part) in
				let material = model.materials[part.materialIndex]
				
				var updatedMaterial = if options.contains(.debugNormals) {
					try CustomMaterial(surfaceShader: MorphEnvironment.shared.debugShader, geometryModifier: geometryModifier, lightingModel: .clearcoat)
				} else {
					try CustomMaterial(from: material, geometryModifier: geometryModifier)
				}
				let targetParts: [MeshResource.Part] = targets.map {
					$0.mesh.contents.models.map { $0 }[submodelId]
						.parts.map { $0 }[partId]
				}
				let vertCountForPart = part.positions.count
				let textureResource = try Self.createTextureForPart(part, targetParts: targetParts, vertCount: vertCountForPart)
				texResources.append(textureResource)
				updatedMaterial.custom.texture = CustomMaterial.Texture(textureResource)
				updatedMaterial.custom.value = weights.values
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
		let positions: [Float] = targetParts.flatMap(\.positions.flattenedElements)
		let basePositions: [Float] = Array(repeating: base.positions.flattenedElements, count: targetParts.count).flatMap { $0 }
		let offsets: [Float] = vDSP.subtract(positions, basePositions)
		let normals: [Float] = targetParts.flatMap {
			$0.normals?.flattenedElements ?? []
		}
		guard positions.count == normals.count else { throw Error.positionsCountNotEqualToNormalsCount }
		let targetCount = targetParts.count
		let elements = (0..<vertCount).flatMap { vertId in
			(0..<targetCount).flatMap { targetId in
				let elementId = ((targetId * vertCount) + vertId) * 3
				let vertRange = elementId..<(elementId + 3)
				return offsets[vertRange] + normals[vertRange]
			}
		}.map { Float16($0) }
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
	/// Updates the ``weights`` for the morph targets, optionally with a linear animation
	/// - Parameters:
	///   - targetWeights: the new ``weights`` to animate to for each of the targets.
	///   - duration: duration of the animation with which the update to the target ``weights`` will be applied. Defaults to 0.
	public mutating func setTargetWeights(_ targetWeights: MorphWeights, duration: TimeInterval = 0) {
		weights = targetWeights
		animator = LinearAnimator(origin: MorphWeights(values: currentWeights), target: targetWeights, duration: duration)
	}
	
	/// Updates the ``weights`` for the morph targets, with advanced animation options
	/// - Parameters:
	///   - targetWeights: the new ``weights`` to animate to for each of the targets.
	///   - animation: the animation with which the update to the target ``weights`` will be applied
	@available(iOS 17.0, macOS 14.0, *)
	public mutating func setTargetWeights(_ targetWeights: MorphWeights, animation: MorphAnimation) {
		weights = targetWeights
		animator = TimelineAnimator(origin: MorphWeights(values: currentWeights), target: targetWeights, animation: animation)
	}
	
	/// Updates the ``weights`` for the morph targets using a custom timeline animation
	/// - Parameters:
	///   - animations: keyframes that will update the target ``weights``
	@available(iOS 17.0, macOS 14.0, *)
	public mutating func setTargetWeights(@KeyframesBuilder<MorphWeights> animations: () -> some Keyframes<MorphWeights>) {
		let timelineAnimator = TimelineAnimator(origin: MorphWeights(values: currentWeights), animations: animations)
		animator = timelineAnimator
		weights = timelineAnimator.timeline.value(progress: 1)
	}
	
	func updated(deltaTime: TimeInterval) -> MorphComponent? {
		var output = self
		guard let event = output.animator?.update(with: deltaTime), event.status == .running else { return nil }
		output.currentWeights = event.weights.values
		return output
	}
}

// MARK: - MorphComponent.Error

public extension MorphComponent {
	/// Errors thrown from ``MorphComponent/init(entity:targets:weights:options:)``
	enum Error: String, Swift.Error {
		/// The `entity` passed to ``MorphComponent/init(entity:targets:weights:options:)`` does not have a `ModelComponent`
		case missingBaseMesh
		
		/// The `targets` passed to ``MorphComponent/init(entity:targets:weights:options:)`` do not have the same number of vertices as the model on the base `entity`, arranged in the same configuration of submodels and parts.
		case targetsNotTopologicallyIdentical
		
		/// The total number of vertices summed from all the `targets` passed to ``MorphComponent/init(entity:targets:weights:options:)`` exceeds the maximum of  33,554,432
		case tooMuchGeometry
		
		/// The array of `targets` passed to ``MorphComponent/init(entity:targets:weights:options:)`` must contain 1, 2, or 3 elements
		case invalidNumberOfTargets
		
		/// Morpher texture creation failed for some reason. Please check the logs for CGImage related failure and raise an issue on the repository
		case couldNotCreateImage
		
		/// The number of normals is different from the number of vertices. All vertices of the model should contain normals.
		case positionsCountNotEqualToNormalsCount
	}
}


// MARK: - Helpers

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

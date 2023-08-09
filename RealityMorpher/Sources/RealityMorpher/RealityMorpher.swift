import RealityKit
import Combine
import Metal
import CoreGraphics

public final class MorphComponentSystem: System {
	enum Error: String, Swift.Error {
		case targetsNotTopologicallyIdentical
	}
	private var subscriptions: [Cancellable] = []
	private let morphGeometryModifier: CustomMaterial.GeometryModifier
	private let device: MTLDevice
	
	public init(scene: Scene) {
		guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal not supported") }
		let library = try! device.makeDefaultLibrary(bundle: .module)
		self.device = device
		morphGeometryModifier = CustomMaterial.GeometryModifier(named: "morph_geometry_modifier", in: library)
		subscriptions = [
			scene.subscribe(to: ComponentEvents.DidAdd.self, componentType: MorphComponent.self) { [weak self] event in
				guard let morpher = event.entity.components[MorphComponent.self] as? MorphComponent else { return }
				try? self?.didAddMorpher(morpher, toEntity: event.entity)
			},
			scene.subscribe(to: ComponentEvents.DidChange.self, componentType: MorphComponent.self) { [weak self] event in
				guard let morpher = event.entity.components[MorphComponent.self] as? MorphComponent else { return }
				self?.didUpdateMorpher(morpher, onEntity: event.entity)
			},
		]
	}

	public func didAddMorpher(_ morpher: MorphComponent, toEntity entity: Entity) throws {
		guard var model = entity.components[ModelComponent.self] as? ModelComponent,
				allTargetsInMorpher(morpher, areTopologicallyIdenticalToModel: model) else {
			throw Error.targetsNotTopologicallyIdentical
		}
		// Because we have no "submesh index" or "part index" within the geometry modifier, each part of the mesh needs to have its own material, where in the original model they might have shared materials
		var updatedContents = MeshResource.Contents()
		updatedContents.instances = model.mesh.contents.instances
		var updatedMaterials: [CustomMaterial] = []
		
		updatedContents.models = MeshModelCollection(model.mesh.contents.models.enumerated().map { (submodelId, submodel) in
			MeshResource.Model(id: submodel.id, parts: submodel.parts.enumerated().map { (partId, part) in
				let material = model.materials[part.materialIndex]
				var updatedMaterial = try! CustomMaterial(from: material, geometryModifier: morphGeometryModifier)
				let targetParts: [MeshResource.Part] = morpher.targets.map { $0.target.mesh.contents.models.map { $0 }[submodelId].parts.map { $0 }[partId] }
				updatedMaterial.custom.texture = createTextureForParts(targetParts)
				updatedMaterial.custom.value = [0, 0, 0, 0]
				let materialIndex = updatedMaterials.count
				updatedMaterials.append(updatedMaterial)
				var newPart = part
				newPart.materialIndex = materialIndex
				return newPart
			})
		})
		let updatedMesh = try MeshResource.generate(from: updatedContents)
		model.materials = updatedMaterials
		model.mesh = updatedMesh
		entity.components[ModelComponent.self] = model
	}
	
	// create texture from part posiotns/ normals
	private func createTextureForParts(_ parts: [MeshResource.Part]) -> CustomMaterial.Texture? {
		guard 1..<4 ~= parts.count, let vertCount = parts.first?.positions.count else { return nil }
		
		let paddingCount = 0// 4 - parts.count
		let padding = Array(repeating: SIMD3<Float>(repeating: 0), count: vertCount * paddingCount)
		let elements = (parts.flatMap { part in
			part.positions.elements
		} + padding + parts.flatMap { part in
			part.normals?.elements ?? []
		} + padding)
			.map { SIMD3<Float16>($0) }
		
		//let elementCount = elements.count //vertCount * 2 * parts.count // multiply by 2 because positions & normals
		let width = min(vertCount, 2048)
		let (quotient, remainder) = elements.count.quotientAndRemainder(dividingBy: width)
		let height = remainder == 0 ? quotient : quotient + 1
		let finalPadding = Array(repeating: SIMD3<Float16>(repeating: 0), count: (width * height) - elements.count)
		let data = (elements + finalPadding).withUnsafeBytes {
			Data($0)
		} as CFData
		let bitmapInfo: CGBitmapInfo = [.floatComponents, .byteOrder16Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
		guard let provider = CGDataProvider(data: data),
			  let image = CGImage(width: width, height: height, bitsPerComponent: 16, bitsPerPixel: 64, bytesPerRow: width * MemoryLayout<SIMD3<Float16>>.stride, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
			  let resource = try? TextureResource.generate(from: image, options: TextureResource.CreateOptions(semantic: .raw, mipmapsMode: .none))
		else { return nil }
		return CustomMaterial.Texture(resource)
	}
	
	private func allTargetsInMorpher(_ morpher: MorphComponent, areTopologicallyIdenticalToModel model: ModelComponent) -> Bool {
		let modelCounts = model.positionCounts
		let allPositionCounts = morpher.targets.map(\.target.positionCounts)
		return allPositionCounts.allSatisfy { counts in
			counts == modelCounts
		}
	}
	
	private func didUpdateMorpher(_ morpher: MorphComponent, onEntity entity: Entity) {
		guard var model = entity.components[ModelComponent.self] as? ModelComponent else { return }
		model.materials = model.materials.map { material in
			guard var customMaterial = material as? CustomMaterial else { return material }
			customMaterial.custom.value = morpher.weights
			return customMaterial
		}
		entity.components[ModelComponent.self] = model
	}
}

private extension ModelComponent {
	var positionCounts: [[Int]] {
		mesh.contents.models.map { model in
			model.parts.map { part in
				part.positions.count
			}
		}
	}
}

public struct MorphComponent: Component {
	public typealias KeyTarget = (key: String, target: ModelComponent)
	let targets: [KeyTarget]
	
	public var weights: SIMD4<Float> = .zero
	
	public init(targets: [KeyTarget]) {
		self.targets = targets
	}
}

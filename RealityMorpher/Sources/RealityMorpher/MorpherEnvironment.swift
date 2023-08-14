//
//  MorpherEnvironment.swift
//  RealityMorpher
//
//  Created by Oliver Dew on 10/08/2023.
//

import Metal
import RealityKit
import RealityMorpherKernels

final class MorpherEnvironment {
	static private(set) var shared = MorpherEnvironment()
	
	let morphGeometryModifiers: [CustomMaterial.GeometryModifier]
	let debugShader: CustomMaterial.SurfaceShader
	
	private init() {
		guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal not supported") }
		let library = try! device.makeDefaultLibrary(bundle: .kernelsModule())
		morphGeometryModifiers = (1...3).map { count in
			CustomMaterial.GeometryModifier(named: "morph_geometry_target_count_\(count)", in: library)
		}
		debugShader = CustomMaterial.SurfaceShader(named: "debug_normals", in: library)
		MorpherSystem.registerSystem()
	}
}

/// System that animates updates to meshes when a ``MorpherComponent`` has an update
private struct MorpherSystem: System {
	
	private let query = EntityQuery(where: .has(MorpherComponent.self) && .has(ModelComponent.self))

	fileprivate init(scene: Scene) {}

	fileprivate func update(context: SceneUpdateContext) {
		for entity in context.scene.performQuery(query) {
			guard let morpher = (entity.components[MorpherComponent.self] as? MorpherComponent)?.updated(deltaTime: context.deltaTime),
				  var model = entity.components[ModelComponent.self] as? ModelComponent
			else { continue }
			
			model.materials = model.materials.enumerated().map { index, material in
				guard var customMaterial = material as? CustomMaterial else { return material }
				let posTexture = morpher.textureResources[index]
				customMaterial.custom.value = .init(morpher.currentWeights, Float(posTexture.vertexCount))
				customMaterial.custom.texture = .init(posTexture.resource)
				return customMaterial
			}
			entity.components.set(model)
			entity.components.set(morpher)
		}
	}
}

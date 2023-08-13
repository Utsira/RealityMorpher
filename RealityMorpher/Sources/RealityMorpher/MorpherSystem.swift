//
//  MorpherSystem.swift
//  RealityMorpher
//
//  Created by Oliver Dew on 10/08/2023.
//

import RealityKit

/// System that animates updates to meshes when a ``MorpherComponent`` has an update
struct MorpherSystem: System {
	
	/// Do not initialize this yourself. Call ``MorpherSystem.registerSystem()`` instead.
	init(scene: Scene) {}
	
	/// Do not call this method, RealityKit will call it every tick.
	func update(context: SceneUpdateContext) {
		for entity in context.scene.performQuery(EntityQuery(where: .has(MorpherComponent.self) && .has(ModelComponent.self))) {
			guard let morpher = (entity.components[MorpherComponent.self] as? MorpherComponent)?.updated(deltaTime: context.deltaTime),
				  var model = entity.components[ModelComponent.self] as? ModelComponent
			else { continue }
			
			model.materials = model.materials.enumerated().map { index, material in
				guard var customMaterial = material as? CustomMaterial else { return material }
				customMaterial.custom.value = morpher.weightsVertexCount
				customMaterial.custom.texture = .init(morpher.textureResources[index])
				return customMaterial
			}
			entity.components.set(model)
			entity.components.set(morpher)
		}
	}
}

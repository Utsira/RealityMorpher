//
//  MorpherSystem.swift
//  RealityMorpher
//
//  Created by Oliver Dew on 10/08/2023.
//

import RealityKit

/// System that animates updates to meshes when a `MorpherComponent` has an update
public final class MorpherSystem: System {
	
	/// Do not initialize this yourself! Call `MorpherSystem.registerComponent()` instead.
	public init(scene: Scene) {}
	
	public func update(context: SceneUpdateContext) {
		for entity in context.scene.performQuery(EntityQuery(where: .has(MorpherComponent.self) && .has(ModelComponent.self))) {
			guard let morpher = (entity.components[MorpherComponent.self] as? MorpherComponent)?.updated(),
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

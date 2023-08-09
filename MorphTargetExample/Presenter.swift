//
//  Presenter.swift
//  MorphTargetExample
//
//  Created by Oliver Dew on 09/08/2023.
//

import RealityKit
import SwiftUI
import RealityMorpher

@Observable
final class Presenter {
	private var morpherSystem: MorphComponentSystem?
	private var billboardSystem: BillboardSystem?
	private var morpherComponent: MorphComponent?
	private var clothEntity: ModelEntity?
	
	func setup(scene: RealityKit.Scene) {
		MorphComponentSystem.registerSystem()
		BillboardSystem.registerSystem()
		
		MorphComponent.registerComponent()
		Billboard.registerComponent()
		Rotatable.registerComponent()
		Draggable.registerComponent()
		
		morpherSystem = MorphComponentSystem(scene: scene)
		billboardSystem = BillboardSystem(scene: scene)
		
		guard let model = try? ModelEntity.loadModel(named: "cloth0", in: .main),
			  let target = try? ModelEntity.loadModel(named: "cloth1", in: .main).model
		else { return }
		let light = DirectionalLight()
		light.look(at: .zero, from: [4, 6, -1], relativeTo: nil)
		
		let camera = PerspectiveCamera()
		camera.look(at: .zero, from: [2, 3, -3], relativeTo: nil)
		
		let root = AnchorEntity()
		root.addChild(model)
		root.addChild(light)
		root.addChild(camera)
		scene.addAnchor(root)
		
		model.generateCollisionShapes(recursive: true)
		model.addComponent(Rotatable())
		model.addComponent(Draggable())
		morpherComponent = MorphComponent(targets: [(key: "bah", target: target)])
		clothEntity = model
		model.components[MorphComponent.self] = morpherComponent
		try? morpherSystem?.didAddMorpher(morpherComponent!, toEntity: clothEntity!) //necessary because morphercomponent not accessible when didadd fires
	}
	
	func setupDebug(scene: RealityKit.Scene) {
		setup(scene: scene)
		guard let clothEntity, let materials = clothEntity.model?.materials as? [CustomMaterial] else { return }
		for (i, materal) in materials.enumerated() {
			guard let resource = materal.custom.texture?.resource else { continue }
			let height = Float(resource.height) / 100
			let plane = ModelEntity(mesh: .generatePlane(width: Float(resource.width) / 100, height: height), materials: [materal])
			plane.addComponent(Billboard())
			clothEntity.addChild(plane)
			plane.transform.translation = [0, -0.5 + (Float(i) * height), 0]
		}
	}
	
	func onTap() {
		guard let currentWeight = morpherComponent?.weights[0] else { return }
		morpherComponent?.weights = [0.5 - currentWeight, 0, 0, 0]
		clothEntity?.components[MorphComponent.self] = morpherComponent
	}
}


extension Entity {
	func addComponent<C: Component>(_ component: C) {
		components[C.self] = component
	}
}

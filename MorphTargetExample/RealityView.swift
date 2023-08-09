//
//  RealityView.swift
//  MorphTargetExample
//
//  Created by Oliver Dew on 02/08/2023.
//

import SwiftUI
import RealityKit

struct RealityView: UIViewRepresentable {
	
	let content: (RealityKit.Scene) -> Void
	
	func makeUIView(context: Context) -> ARView {
		let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
		content(view.scene)
		for rotatable in view.scene.performQuery(EntityQuery(where: .has(Rotatable.self) && .has(CollisionComponent.self))) {
			view.installGestures(.rotation, for: rotatable as! HasCollision)
		}
		for draggable in view.scene.performQuery(EntityQuery(where: .has(Draggable.self) && .has(CollisionComponent.self))) {
			view.installGestures(.translation, for: draggable as! HasCollision)
		}
		return view
	}
	
	func updateUIView(_ uiView: ARView, context: Context) {
		
	}
}

struct Rotatable: Component {}
struct Draggable: Component {}
struct Billboard: Component {}

final class BillboardSystem: System {
	private var camera: Entity?
	
	init(scene: RealityKit.Scene) {
		
	}
	
	func update(context: SceneUpdateContext) {
		if camera == nil {
			camera = retrieveCamera(scene: context.scene)
		}
		guard let camera else { return }
		for entity in context.scene.performQuery(EntityQuery(where: .has(Billboard.self))) {
			let cameraPosition = entity.convert(position: .zero, from: camera)
			entity.look(at: -cameraPosition, from: .zero, relativeTo: entity)
		}
	}
	
	private func retrieveCamera(scene: RealityKit.Scene) -> Entity? {
		scene.performQuery(EntityQuery(where: .has(PerspectiveCameraComponent.self))).first(where: {_ in true })
	}
}

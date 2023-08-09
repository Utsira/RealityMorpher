//
//  ContentView.swift
//  MorphTargetExample
//
//  Created by Oliver Dew on 01/08/2023.
//

import SwiftUI
import RealityKit
import RealityMorpher

struct ContentView: View {
	
	@State private var presenter = Presenter()
	
    var body: some View {
		RealityView { scene in
			presenter.setup(scene: scene)
		}
		.onTapGesture {
			presenter.onTap()
		}
		.edgesIgnoringSafeArea(.all)
        
    }
}

@Observable
final class Presenter {
	private var morpherSystem: MorphComponentSystem?
	private var morpherComponent: MorphComponent?
	private var clothEntity: ModelEntity?
	
	func setup(scene: RealityKit.Scene) {
		MorphComponentSystem.registerSystem()
		MorphComponent.registerComponent()
		morpherSystem = MorphComponentSystem(scene: scene)
		
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

		morpherComponent = MorphComponent(targets: [(key: "bah", target: target)])
		clothEntity = model
		model.components[MorphComponent.self] = morpherComponent
		try? morpherSystem?.didAddMorpher(morpherComponent!, toEntity: clothEntity!)
	}
	
	func onTap() {
		guard let currentWeight = morpherComponent?.weights[0] else { return }
		morpherComponent?.weights = [0.5 - currentWeight, 0, 0, 0]
		clothEntity?.components[MorphComponent.self] = morpherComponent
	}
}

#Preview {
    ContentView()
}

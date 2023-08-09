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
		return view
	}
	
	func updateUIView(_ uiView: ARView, context: Context) {
		
	}
}

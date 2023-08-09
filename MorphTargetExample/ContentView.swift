//
//  ContentView.swift
//  MorphTargetExample
//
//  Created by Oliver Dew on 01/08/2023.
//

import SwiftUI

struct ContentView: View {
	
	@State private var presenter = Presenter()
	
    var body: some View {
		RealityView { scene in
			presenter.setupDebug(scene: scene)
		}
		.onTapGesture {
			presenter.onTap()
		}
		.edgesIgnoringSafeArea(.all)
        
    }
}

#Preview {
    ContentView()
}

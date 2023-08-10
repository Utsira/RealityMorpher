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
	
	let morphGeometryModifier: CustomMaterial.GeometryModifier
	let debugShader: CustomMaterial.SurfaceShader
	
	private init() {
		guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal not supported") }
		let library = try! device.makeDefaultLibrary(bundle: .kernelsModule())
		morphGeometryModifier = CustomMaterial.GeometryModifier(named: "morph_geometry_modifier", in: library)
		debugShader = CustomMaterial.SurfaceShader(named: "debug_normals", in: library)
	}
}

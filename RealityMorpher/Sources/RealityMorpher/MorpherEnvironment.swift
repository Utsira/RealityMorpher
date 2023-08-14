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

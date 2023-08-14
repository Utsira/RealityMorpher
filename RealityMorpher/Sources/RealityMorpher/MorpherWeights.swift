//
//  MorpherWeights.swift
//  
//
//  Created by Oliver Dew on 11/08/2023.
//

import simd
import SwiftUI

/// Animatable wrapper around the weights of the morph targets.
@dynamicMemberLookup struct MorpherWeights: Animatable {
	private(set) var values: SIMD4<Float>
	
	var animatableData: SIMD4<Float> {
		get { values }
		set { values = newValue }
	}
	
	/// The weights of up to 4 morph targets
	/// - Parameter weights: The weights of the targets. Element 0 of the array describes the desired weighting of element 0 in the `targets` array that was passed to the ``MorpherComponent`` initializer ``MorpherComponent/init(entity:targets:options:)``. Each element is typically in the range of 0 to 1. A weight of 0 indicates this morph target is ignored, 1 means the model has completely deformed to the target position.
	init(_ weights: [Float]) {
		var elements = weights
		if weights.count < MorpherEnvironment.maxTargetCount {
			elements.append(contentsOf: Array(repeating: 0, count: MorpherEnvironment.maxTargetCount - weights.count))
		}
		self.init(values: SIMD4(elements[0..<MorpherEnvironment.maxTargetCount]))
	}

	init(values: SIMD4<Float>) {
		self.values = values
	}
	
	subscript(dynamicMember keyPath: KeyPath<SIMD4<Float>, Float>) -> Float {
		values[keyPath: keyPath]
	}
	
	static var zero: MorpherWeights {
		MorpherWeights(values: .zero)
	}
}

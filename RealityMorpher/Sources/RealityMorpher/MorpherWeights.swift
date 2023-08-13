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
	private(set) var values: SIMD3<Float>
	
	var animatableData: SIMD3<Float> {
		get { values }
		set { values = newValue }
	}
	
	/// The weights of up to 3 morph targets
	/// - Parameter weights: The weights of the targets. Element 0 of the array describes the desired weighting of element 0 in the `targets` array that was passed to the ``MorpherComponent`` initializer ``MorpherComponent/init(entity:targets:options:)``. Each element is typically in the range of 0 to 1. A weight of 0 indicates this morph target is ignored, 1 means the model has completely deformed to the target position.
	init(_ weights: [Float]) {
		var elements = weights
		if weights.count < 3 {
			elements.append(contentsOf: Array(repeating: 0, count: 3 - weights.count))
		}
		self.init(values: SIMD3(elements[0..<3]))
	}

	init(values: SIMD3<Float>) {
		self.values = values
	}
	
	subscript(dynamicMember keyPath: KeyPath<SIMD3<Float>, Float>) -> Float {
		values[keyPath: keyPath]
	}
	
	static var zero: MorpherWeights {
		MorpherWeights(values: .zero)
	}
}

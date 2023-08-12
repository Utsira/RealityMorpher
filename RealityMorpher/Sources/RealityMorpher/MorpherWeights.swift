//
//  MorpherWeights.swift
//  
//
//  Created by Oliver Dew on 11/08/2023.
//

import simd
import SwiftUI

/// The weights of up to 3 morph targets.
@dynamicMemberLookup public struct MorpherWeights: Animatable, ExpressibleByArrayLiteral {
	public private(set) var values: SIMD3<Float>
	
	public var animatableData: SIMD3<Float> {
		get { values }
		set { values = newValue }
	}
	
	/// The weights of up to 3 morph targets
	/// - Parameter targets: The weights of the targets, expressed as a SIMD3. Element 0 of the SIMD3 describes the desired weighting of element 0 in the `targets` array that was passed to the ``MorpherComponent`` initializer ``MorpherComponent/init(entity:targets:options:)``. Each element is typically in the range of 0 to 1. A weight of 0 indicates this morph target is ignored, 1 means the model has completely deformed to the target position.
	public init(_ targets: SIMD3<Float>) {
		self.values = targets
	}
	
	public init(arrayLiteral elements: Float...) {
		values = SIMD3(elements)
	}
	
	public subscript(dynamicMember keyPath: KeyPath<SIMD3<Float>, Float>) -> Float {
		values[keyPath: keyPath]
	}
	
	public static var zero: MorpherWeights {
		MorpherWeights(.zero)
	}
}

//
//  MorphWeights.swift
//  
//
//  Created by Oliver Dew on 11/08/2023.
//

import simd
import SwiftUI

/// Describes the weights of up to 4 morph targets.
///
/// Each component of the ``values`` describes the weighting applied to one of the targets contained in the ``MorphComponent``. Each element is typically in the range of 0 to 1. A weight of 0 indicates this morph target is ignored, 1 means the model has completely deformed to the target position.
@dynamicMemberLookup public struct MorphWeights: Animatable, ExpressibleByArrayLiteral {
	/// The weights of the targets.
	private(set) public var values: SIMD4<Float>
	
	public var animatableData: SIMD4<Float> {
		get { values }
		set { values = newValue }
	}
	
	/// - Parameter weights: The weights of the targets contained in the ``MorphComponent``
	public init(_ weights: [Float]) {
		var elements = weights
		if weights.count < MorphEnvironment.maxTargetCount {
			elements.append(contentsOf: Array(repeating: 0, count: MorphEnvironment.maxTargetCount - weights.count))
		}
		self.init(values: SIMD4(elements[0..<MorphEnvironment.maxTargetCount]))
	}

	/// - Parameter values: The weights of the targets. Each component corresponds to an element of the targets array container in the ``MorphComponent``.
	public init(values: SIMD4<Float>) {
		self.values = values
	}
	
	public init(arrayLiteral elements: Float...) {
		self.init(elements)
	}
	
	public subscript(dynamicMember keyPath: KeyPath<SIMD4<Float>, Float>) -> Float {
		values[keyPath: keyPath]
	}
	
	public static var zero: MorphWeights {
		MorphWeights(values: .zero)
	}
}

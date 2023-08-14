#  Reality Morpher

Adds Morph Target / Key Shape animations to RealityKit

### Requirements

- A maximum of 4 morph targets can be added to any Entity
- The morph targets must all be topologically identical to the base model (in other words have the same number of submodels, parts, and vertices)
- The 4 targets cannot have more than 33,554,432 vertices combined (probably plenty, right?)
- The animation has half-width (Float16) precision

### TODO

- Use tuples instead of array? (target t0: ModelComponent, _ t1: ModelComponnet? = nil, _ t2: ModelComponnet? = nil )
- MorpherAnimation be an enum (expose keyframeTimeline more)?

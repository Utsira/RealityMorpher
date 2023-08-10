#  Reality Morpher

Adds Morph Target / Key Shape animations to RealityKit

### Requirements

- A maximum of 3 morph targets can be added to any Entity
- The morph targets must all be topologically identical to the base model (in other words have the same number of submodels, parts, and vertices)
- The 3 targets cannot have more than 33,554,432 vertices combined (probably plenty, right?)
- The animation has half-width (Float16) precision

### TODO

- animation curves
- docC
- different interpolation modes

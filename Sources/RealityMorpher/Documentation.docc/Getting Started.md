# Getting Started

Follow these steps to get up and running

## Overview

`RealityMorpher` fully integrates with RealityKit's Entity Component System. The core functionality is encapsulated within ``MorphComponent``. After registering the component, you instantiate it with some target geometries and attach it to a `ModelEntity`. Use one of the `setTargetWeights` methods, such as ``MorphComponent/setTargetWeights(_:animation:)``, to animate a transition between the base and one or more of the target geometries.

### Registration

You must call the static registration method ``MorphComponent/registerComponent()`` on ``MorphComponent`` before you start using RealityNorpher.

### Adding the Morpher to an Entity

When you instantiate a ``MorphComponent`` you pass the base Entity you intend to add the component to, as well as an array of the target models: ``MorphComponent/init(entity:targets:weights:options:)``. After creating the component, you must add it to the base entity:

```swift
MorphComponent.registerComponent()
do {
	let model = try ModelEntity.loadModel(named: "rock"),
	let target = try ModelEntity.loadModel(named: "rock_shattered").model
	let morphComponent = try MorphComponent(entity: model, targets: [target].compactMap { $0 })
	model.components.set(morphComponent)
} catch {
	// handle errors
}
```

### Blending between Morph Targets

Animate between the different Morph Targets by assigning a weight for each target. Up to 4 weights are passed in a ``MorphWeights`` object. A weight of 0 means the corresponding target has no influence at all, while a weight of 1.0 means it is fully applied.
- ``MorphComponent/setTargetWeights(_:animation:)``

### Limitations

- A maximum of 4 morph targets can be added to any Entity
- The morph targets must all be topologically identical to the base model (in other words have the same number of submodels, parts, and vertices)
- The 4 targets cannot have more than 33,554,432 vertices combined
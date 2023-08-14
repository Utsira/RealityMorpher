# ``RealityMorpher``

Animate smooth transitions between an entity's base geometry and up to four target geometries

## Overview

Manage these geometry transitions by attaching a ``MorpherComponent`` to a `ModelEntity`. The morpher maintains a set of up to four target geometries and associated weights. When all the weights are zero, the Entity takes the form of its base mesh, supplied by its `ModelComponent`. When you use the ``MorpherComponent/setTargetWeights(_:animation:)`` method to increase one or more of the weights to 1.0, the Entity takes on the form of the corresponding target geometry, smoothly interpolating each of its positions and normals between the base and the target. If you use a variety of weight values for several targets, the surface takes a form that proportionally interpolates between the target geometries.

The base geometry and all target geometries must be topologically identical—that is, they must contain the same number and structural arrangement of vertices.

## Topics

### Essentials

- ``MorpherComponent``

### Animating transitions

- ``MorpherWeights``
- ``MorpherAnimation``

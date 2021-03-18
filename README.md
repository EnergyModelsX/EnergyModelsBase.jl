# EnergyModelsBase

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

EnergyModelsBase is the foundation package to build flexible multi-energy-carrier energy systems models. It is designed to model the basic operations of various generation, conversion and storage technologies. EnergyModelsBase is designed to enable optimization of operations, and to be be easily extendible to investment models, and/or to include new technologies or more detailed models of key technologies.

This package is currently experimental/proof-of-concept and under heavy development. Expect breaking changes.

## Usage

```julia
using EnergyModelsBase
const EMB = EnergyModelsBase

EMB.run_model("/path/to/input/data")
```

## TODO

* types to distinguish links?
  - direct
  - transmission (length)
* direct/transmission _and_ formulation?



## Funding

EnergyModelsBase was funded by the Norwegian Research Council in the project Clean Export, project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)
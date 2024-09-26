# EnergyModelsBase

**EnergyModelsBase** is an operational, multi nodal energy system model, written in Julia.
The model is based on the [`JuMP`](https://jump.dev/JuMP.jl/) optimization framework.
It is a multi carrier energy model, where the definition of the carriers are fully up to the user of the model.
One of the primary design goals was to develop a model that can easily be extended with new functionalities without the need to understand and remember every variable and constraint in the model.

For running a basic energy system model, only the base technology package `EnergyModelsBase` and the time structure package
[`TimeStruct`](https://sintefore.github.io/TimeStruct.jl/) are needed.

The main package provides simple descriptions for energy sources, sinks, conversion, and storage units.
It corresponds to an operational model without geographic features.

Other packages can the optionally be added if specific functionality or technology nodes are needed. The most important packages are

- [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/):
   this package makes it possible to easily extend your energy model with different
   geographic areas, where transmission can be set to allow for the transport of
   resources between the different areas.
- [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/):
   this package implements functionality for investments, where the length of the
   investment periods are fully flexible and is decided by setting the time
   structure.

Open Packages implementing technology specific nodes:

- [`EnergyModelsRenewableProducers`](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/): implements `NonDisRES` for intermittent (**Non**-**Dis**patchable) **R**enewable **E**nergy **S**ources and `HydroStor` modeling a regulated hydro storage plant as well as `PumpedHydroStor` modelling a pumped hydro storage plant.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/optimization-variables.md",
    "manual/constraint-functions.md",
    "manual/data-functions.md",
    "manual/simple-example.md",
    "manual/investments.md",
    "manual/NEWS.md",
]
Depth = 1
```

## Description of the nodes

```@contents
Pages = [
    "nodes/source.md",
]
Depth = 1
```

## How to guides

```@contents
Pages = [
    "how-to/create-new-node.md",
    "how-to/utilize-timestruct.md",
    "how-to/update-models.md",
    "how-to/contribute.md",
]
Depth = 1
```

## Library outline

```@contents
Pages = [
    "library/public.md",
    "library/internals/reference.md",
]
Depth = 1
```

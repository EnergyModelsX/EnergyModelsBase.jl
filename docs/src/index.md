# EnergyModelsBase.jl

```@docs
EnergyModelsBase
```

**CleanExport** is an operational, multi nodeal energy system model, written in Julia.
The model is based on the [`JuMP`](https://jump.dev/JuMP.jl/stable/) optimization framework.
It is a multi carrier energy model, where the definition of the resources are fully up to the user of the model.
One of the primary design goals was to develop a model that can eaily be extended with new functionality without the need to understand and remember every variable and constraint in the model.

For running a basic energy system model, only the base technology package
[`EnergyModelsBase.jl`](https://clean_export.pages.sintef.no/energymodelsbase.jl/)
and the time structure package
[`TimeStruct.jl`](https://gitlab.sintef.no/julia-one-sintef/timestruct.jl)
is needed.

The main package provides simple descriptions for energy sources, sinks, conversion, and storage units.
It corresponds to an operational model without geographic features.

Other packages can the optionally be added if specific functionality or technology nodes are needed. The most important packages are

- [`EnergyModelsGeography.jl`](https://clean_export.pages.sintef.no/energymodelsgeography.jl/):
   this package makes it possible to easily extend your energy model different
   geographic areas, where transmission can be set to allow for the transport of
   resources between the different areas.
- [`EnergyModelsInvestments.jl`](https://clean_export.pages.sintef.no/energymodelsinvestments.jl/):
   this package implements functionality for investments, where the length of the
   investment periods are fully flexible and is decided by setting the time
   structure.

Packages implementing technology specific nodes:

- [`EnergyModelsCO2.jl`](https://clean_export.pages.sintef.no/EnergyModelsCO2.jl/): implementing a CO2-storage node.
- [`EnergyModelsHydrogen.jl`](https://clean_export.pages.sintef.no/energymodelshydrogen.jl/): implementing an electrolyser node.
- [`EnergyModelsRenewableProducers.jl`](https://clean_export.pages.sintef.no/energymodelsrenewableproducers.jl/): implements `NonDisRES` for intermittent renewable energy sources and `RegHydroStor` modeling a regulated hydro storage.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/nodes.md"
    "manual/simple-example.md"
]
```

## Library outline

```@contents
Pages = [
    "library/public.md",
    "library/internals/optimization-variables.md",
    "library/internals/constraint-functions.md",
    "library/internals/reference.md",
]
```

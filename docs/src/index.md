# EnergyModelsBase.jl

This Julia package provides an operational, multi nodal model .

The first node [`NonDisRES`](@ref) models a non-dispatchable renewable energy source, like 
wind power, solar power, or run of river hydropower. These all use intermittent energy 
sources in the production of energy, so the maximum production capacity varies with the 
availability of the energy source at the time. This struct is described in detail in 
[Library/Public](@ref sec_lib_public).

The other node [`RegHydroStor`](@ref) implements a regulated hydropower storage plant, 
both with- and without pumps for filling the reservoir with excess energy. This struct is 
also documented in [Library/Public](@ref sec_lib_public).


## `EnergyModelsBase.jl`

This should be a short pitch about the energy system model, and how it differs from other 
models.


## Manual outline
```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/simple-example.md"
]
```

## Library outline
```@contents
Pages = ["library/public.md"]
```
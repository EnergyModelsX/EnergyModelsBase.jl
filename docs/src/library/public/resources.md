# [Resources](@id lib-pub-res)

`Resource`s correspond to the mass/energy that is converted or transported within an energy system.
`Resource`s are discrete, that is they do not have as default additional variables, *e.g.* pressure or temperature, associated with them.
Instead, they are implemented through flows and levels, as explained in *[Optimization variables](@ref man-opt_var)*.

## Index

```@index
Pages = ["resources.md"]
```

## [`Resource` types](@id lib-pub-res-types)

The following resources are implemented in `EnergyModelsBase`.
`EnergyModelsBase` differentiates between `ResourceCarrier` and `ResourceEmit` resources.
The key difference between both is that `ResourceEmit` resources can have emissions, *e.g.*, CO₂ or methane.
Emissions are accounted for and can have either a cap and/or a price associated with them.

One important field for a resource is the CO₂ intensity (`co2_int`).
CO₂ is handled differently than other emissions as the emissions are fundamental properties of a fuel based on the carbon content.

```@docs
Resource
ResourceCarrier
ResourceEmit
```

## [Functions for accessing fields of `Resource` types](@id lib-pub-res-fun_field)

The following functions are declared for accessing fields from a `Resource` type.
If you want to introduce new `Resource` types, it is important that this function are either functional for your new types or you have to declare a corresponding function.

```@docs
co2_int
```

## [Functions for grouping `Resource` types](@id lib-pub-res-fun_family)

The resources of a case are segmented by type before the resource-specific functions ([`variables_flow_resource`](@ref), [`constraints_resource`](@ref), and [`constraints_couple_resource`](@ref)) are called.
The following function controls the segmentation.
It is only relevant if you introduce a family of resource types that should be handled together, see the page *[Extend resource functionality](@ref how_to-res_funct)*.

```@docs
EnergyModelsBase.resource_family
```
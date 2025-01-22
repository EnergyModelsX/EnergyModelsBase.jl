# [Case description](@id lib-pub-case)

`EnergyModelsBase` data is included in a case.
The case was previously declared as a dictionary, but is moved from Version 0.10 to a type for improved flexibility.
The following page explains the concepts of the case type.

## Index

```@index
Pages = ["case_element.md"]
```

## [Elements](@id lib-pub-case-element)

All types in `EnergyModelsBase` that require mathemeatical constraints are considered as elements.
Elements allow for the incorporations of mathematical constraints.
`EnergyModelsBase` includes two types of `AbstractElement`s, *[nodes](@ref lib-pub-nodes)* and *[links](@ref lib-pub-links)*.
`Node`s convert, store, supply or demand resources.
They do not possess any direct connections.
The connections are incorporated through `Link`s which transport resources between different nodes.

```@docs
AbstractElement
```

## [Case type](@id lib-pub-case-case)

The case type is used as input to `EnergyModelsBase` models.
It contains all information for building a model using the [`create_model`](@ref) function.

The fields of the case dictionary correspond to:

1. **`T::TimeStructure`** is the time structure for which the model should be constructed.
   Time structures are created using the the [`TimeStruct`](https://sintefore.github.io/TimeStruct.jl/stable/) package.
   `EnergyModelsBase` supports all time structures included in `TimeStruct`.
   However, storage balances may violate the upper and lower bound when the time structure includes [`OperationalScenarios](@extref TimeStruct.OperationalScenarios).
   In general, it is preferable to utilize either a [`TwoLevel`](@extref TimeStruct.TwoLevel) or [`TwoLevelTree`](@extref TimeStruct.TwoLevelTree) to properly calculate the operational costs and the emissions.
2. **`products::Vector{<:Resource}`** is a vector of all considered *[resources](@ref lib-pub-res)* in the analysis.
   In theory, it is not necessary that this vector includes all resources, although it must include all insatnces of [`ResourceEmit`](@ref).
3. **`elements::Vector{Vector}`** is a vector of the vectors of [`AbstractElement`](@ref)s of the analysis, as described above.
   This `Vector{Vector}` can be extended with additional types for which variables and constraints should be introduced.

   !!! note "Type requirement"
       The elements must be provided as `elements::Vector{Vector}`.
       This implies that if you only want to include a single [`AbstractElement`](@ref), *e.g.*, only a `Vector{<:Node}`, you **must** add an additional empty vector of an `AbstractElement`, *e.g.*, `Link`
       Otherwise, it is not possible to create a case.

4. **`couplings::Vector{Vector{Function}}`** is a vector of vector of functions.
   The couplings include connections between two distinctive `AbstractElement` types.
   Coupling implies in this context that two `AbstractElement` type, *i.e.*, [`Link`](@ref) and [`Node`](@ref EnergyModelsBase.Node) have common constraints.
   `EnergyModelsBase` provides as potential functions [`f_nodes`](@ref) and [`f_links`](@ref) in the coupling.

```@docs
EMXCase
```

## [Functions for accessing different information](@id lib-pub-links-fun_field)

```@docs
f_time_struct
f_products
f_elements_vec
f_couplings
f_nodes
f_links
```

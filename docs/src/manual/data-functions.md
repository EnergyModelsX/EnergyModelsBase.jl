# [ExtensionData functions](@id man-data_fun)

The package provides the wildcard [`ExtensionData`](@ref) type as outlined in the *[Extensions to the model](@ref man-phil-ext)* section of the philosophy page.
`ExtensionData` can be utilized to extend the functionality of the model through dispatching on its type.
The following function is included in all reference `create_node` functions, except for `Storage` types

```julia
# Iterate through all data and set up the constraints corresponding to the data
for data ∈ node_data(n)
    constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
end
```

There is always a fallback option if a `ExtensionData` is specified, but no functions are provided:

```julia
constraints_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::ExtensionData) = nothing
```

Its application is best explained by the implemented functionality for emissions.

## [Emissions data](@id man-data_fun-emissions)

Emissions data is an application of extensions *via* the application of the wildcard `data` field in the nodes.
It allows to consider:

1. no emissions of a node (no `EmissionsData` type has to be provided),
2. energy usage related emissions of a node, that is emissions through the utilization of an energy carrier ([`EmissionsEnergy`](@ref)) given as input,
3. the combination of process emissions and energy usage related emissions ([`EmissionsProcess`](@ref)),
4. CO₂ capture of energy usage related emissions ([`CaptureEnergyEmissions`](@ref)),
5. CO₂ capture of process emissions ([`CaptureProcessEmissions`](@ref)), and
6. CO₂ capture of both process and energy usage related emissions ([`CaptureProcessEnergyEmissions`](@ref)).

The individual fields of the different types are described in the *[Public interface](@ref lib-pub-mod_data-data)*.

The extension is then implemented through the functions

```julia
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsEnergy)
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsProcess)
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureEnergyEmissions)
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::CaptureProcessEmissions)
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::CaptureProcessEnergyEmissions)
```

in the file `data_functions.jl`.
Correspondingly, we require only a single implementation of a `Node` to investigate multiple different emission scenarios, depending on the chosen `EmissionsData`.
Both `EmissionsEnergy` and `EmissionsProcess` can handle input similar to the other `EmissionsData` types, allowing for a fast switch between individual emission configurations.

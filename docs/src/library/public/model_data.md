
# [Model and data](@id lib-pub-mod_data)

### [`EnergyModel`](@id lib-pub-mod_data-types)

The type `EnergyModel` is used for creating the global parameters of a model.
It can be as well used for extending `EnergyModelsBase` as described in the section *[Extensions to the model](@ref man-phil-ext)*.
`EnergyModelsBase` provides an `OperationalModel` for analyses with given capacities.
`OperationalModel` contains some key information for the model such as the emissions limits and penalties for each `ResourceEmit`, as well as the `ResourceEmit` instance of CO₂.

```@docs
EnergyModel
OperationalModel
```

### [Functions for accessing fields of `EnergyModel` types](@id lib-pub-mod_data-fun_field_model)

The following functions are declared for accessing fields from an `EnergyModel` type.

!!! warning
    If you want to introduce new `EnergyModel` types, it is important that the functions `emission_limit`, `emission_price`, and `co2_instance` are either functional for your new types or you have to declare corresponding functions.
    The first approach can be achieved through using the same name for the respective fields.

```@docs
emission_limit
emission_price
co2_instance
```

## [Additional data](@id lib-pub-mod_data-data)

Emission data are used to provide the individual nodes with potential emissions.
The approach is also explained on the page *[ExtensionData functions](@ref man-data_fun)*.

### [`ExtensionData` and `Emission` types](@id lib-pub-mod_data-data-types)

`ExtensionData` types are introduced for introducing additional parameters, variables, and constraints to the `Node`s.
The approach of using the `data` field of `Node`s is explained on the page *[ExtensionData functions](@ref man-data_fun)*.
`EmptyData` is no longer relevant for the modelling, but it is retained for avoiding any problems with existing models.

```@docs
ExtensionData
EmptyData
```

`EmissionData` is one approach for utilizing the `data` field of `Node`s.
The thought process with `EmissionData` is to provide the user with options for each individual node to include emissions and potentially capture or not.
The individual types can be used for all included *[reference `Node`s](@ref lib-pub-nodes-ref)*, although capture is not possible for `Sink` nodes due to the lack of an output.
This explained in more detail on the corresponding node page.

```@docs
EmissionsData
CaptureData
EmissionsEnergy
EmissionsProcess
CaptureEnergyEmissions
CaptureProcessEmissions
CaptureProcessEnergyEmissions
```

### [Functions for accessing fields of `EmissionsData` types](@id lib-pub-mod_data-data-fun_field)

The following functions are declared for accessing fields from an `EmissionsData` type.

!!! warning
    If you want to introduce new `EmissionsData` types, it is important that the functions `co2_capture` and `process_emissions` are either functional for your new types or you have to declare corresponding functions.
    The first approach can be achieved through using the same name for the respective fields.

```@docs
co2_capture
process_emissions
```

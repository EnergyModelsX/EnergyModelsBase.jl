# [Public interface](@id sec_lib_public)

## Module

```@docs
EnergyModelsBase
```

## Resources

`Resource`s correspond to the mass/energy that is converted or transported within an energy system.
`Resource`s are discrete, that is they do not have as default additional variables, *e.g.* pressure or temperature, associated with them.
Instead, they are implemented through flows and levels, as explained in *[Optimization variables](@ref optimization_variables)*.

### `Resource` types

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

### Functions for accessing fields of `Resource` types

The following functions are declared for accessing fields from a `Resource` type.
If you want to introduce new `Resource` types, it is important that this function are either functional for your new types or you have to declare a corresponding function.

```@docs
co2_int
```

## Nodes

`Node`s are used in `EnergyModelsBase` to convert `Resource`s.
They are coupled to the rest of the system through the *[Flow variables](@ref var_flow)*.
Nodes are the key types for extending `EnergyModelsBase` through dispatch.
You can find an introduction of the different node types on the page *[Creating a new node](@ref create_new_node)*

### Abstract `Node` types

The following abstract node types are implemented in the `EnergyModelsBase`.
These abstract types are relevant for dispatching in individual functions.

```@docs
Source
NetworkNode
Sink
Storage
Availability
```

### [Reference node types](@id sec_lib_public_refnodes)

The following composite types are implemented in the `EnergyModelsBase`.
They can be used for describing a simple energy system without any non-linear or binary based expressions.
Hence, there are, *e.g.*, no operation point specific efficiencies implemented.

```@docs
RefSource
RefNetworkNode
RefSink
RefStorage
GenAvailability
```

### [Storage behaviours](@id sec_lib_public_storbehav)

`EnergyModelsBase` provides several different storage behaviours for calculating the level balance of a `Storage` node.
In general, the concrete storage behaviours are ready to use and should account for all eventualities.

```@docs
Accumulating
AccumulatingEmissions
Cyclic
CyclicRepresentative
CyclicStrategic
```

!!! note
    We have not yet supported upper and lower bound constraints in the case of using `OperationalScenarios`.
    While the calculation of the overall level balance and the operational costs is consistent, it can happen that the upper and lower bound of the storage level is violated.

    This impacts specifically `CyclicStrategic`.

### [Storage parameters](@id sec_lib_public_storpar)

Storage parameters are used for describing different parameters for the idnividual capacities of a `Storage` node.
In practice, `Storage` nodes can have three different capacities:

1. charge, that is a capacity for charging the `Storage` node,
2. level, that is the amount of energy/mass that can be stored, and
3. discharge, that is a capacity for discharging the `Storage` node.

In general, each of the individual capacities can have an assigned capacity, variable OPEX, and fixed OPEX.
Furthermore, it is possible to only have a variable OPEX.
To this end, multiple composite types are defined.

```@docs
StorCapOpex
StorCap
StorCapOpexVar
StorCapOpexFixed
StorOpexVar
```

When dispatching on the individual type, it is also possible to use the following unions:

```@docs
EMB.UnionOpexFixed
EMB.UnionOpexVar
EMB.UnionCapacity
```

### [Functions for accessing fields of `Node` types](@id functions_fields_node)

The following functions are declared for accessing fields from a `Node` type.

!!! warning
    If you want to introduce new `Node` types, it is important that these functions are either functional for your new types or you have to declare corresponding functions.
    The first approach can be achieved through using the same name for the respective fields.

    The functions `storage_resource` is only required for `Storage` nodes, when you plan to use the implemented constraint function `constraints_flow_in`.
    The functions `surplus_penalty` and `deficit_penalty` are only required for `Sink` nodes if you plan to use the implemented constraint function `constraints_opex_var`.

```@docs
capacity
opex_var
opex_fixed
inputs
outputs
node_data
charge
level
discharge
storage_resource
surplus_penalty
deficit_penalty
```

### Functions for identifying `Node`s

The following functions are declared for filtering on `Node` types.

!!! warning
    If you want to introduce new `Node` types, it is important that the functions `has_input`, `has_output`, and `has_emissions` are either functional for your new types or you have to declare corresponding functions.
    The first approach can be achieved through using the same name for the respective fields.

    The functions `nodes_input`, `nodes_output`, and `nodes_emissions` are not used in the model as they are replaced by the build in filter function as, *e.g.*, `filter(has_input, 𝒩)`.
    In practice, they provide a pre-defined approach for filtering nodes and do not require additional modifications.
    They can be used in potential extensions.

```@docs
nodes_input
nodes_output
nodes_emissions
has_input
has_output
has_emissions
has_charge
has_discharge
```

## Links

`Link`s are connecting the individual `Node`s for the exchange of energy/mass.
`Link`s are directional, that is transport of mass/energy is only allowed in a single direction.

### `Link` types

The following types for links are implemented in `EnergyModelsBase`.
The thought process is to dispatch on the [`EMB.Formulation`](@ref) of a link as additional option.
This is in the current stage not implemented.

```@docs
Link
Direct
Linear
```

### Functions for accessing fields of `Link` types

The following functions are declared for accessing fields from a `Link` type.

!!! warning
    If you want to introduce new `Link` types, it is important that the function `formulation` is either functional for your new types or you have to declare a corresponding function.
    The first approach can be achieved through using the same name for the respective fields.

```@docs
formulation
```

## Model and data

### `EnergyModel` and `Data` types

The type `EnergyModel` is used for creating the global parameters of a model.
It can be as well used for extending `EnergyModelsBase` as described in the section *[Extensions to the model](@ref sec_phil_ext)*.
`EnergyModelsBase` only provides an `OperationalModel` while `InvestmentModel` is added through the extension [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/)

```@docs
EnergyModel
OperationalModel
```

In addition, the following `Data` types are introduced for introducing additional parameters, variables, and constraints to the `Node`s.
The approach of using the `data` field of `Node`s is explained on the page *[Data functions](@ref data_functions)*.
`EmptyData` is no longer relevant for the modelling, but it is retained for avoiding any problems with existing models.

```@docs
Data
EmptyData
```

### Functions for accessing fields of `EnergyModel` types

The following functions are declared for accessing fields from a `EnergyModel` type.

!!! warning
    If you want to introduce new `EnergyModel` types, it is important that the functions `emission_limit`, `emission_price`, and `co2_instance` are either functional for your new types or you have to declare corresponding functions.
    The first approach can be achieved through using the same name for the respective fields.

```@docs
emission_limit
emission_price
co2_instance
```

## Functions for running the model

The following functions are provided for both creating a model using `EnergyModelsBase` and solving said model.
Both functions have the input `case` and `model`.
`run_model` calls `create_model` in the function, hence, it is not necessary to call the function beforehand.

The `case` dictionary has to follow a certain outline.
In this case, it is simplest to look at the provided *[examples](https://github.com/EnergyModelsX/EnergyModelsBase.jl/tree/main/examples)*.

!!! note
    We are currently debating to replace the dictionary used for `case` as well with a composite type.
This will lead to breacking changes, but should be simple to adjust for.

```@docs
create_model
run_model
```

## Functions for extending the model

The following functions are used for developing new nodes.
See the page *[Creating a new node](@ref create_new_node)* for a detailed explanation on how to create a new node.

```@docs
variables_node
create_node
```

## Constraint functions

The following functions can be used in new developed nodes to include constraints.
See the pages *[Constraint functions](@ref constraint_functions)* and *[Data functions](@ref data_functions)* for a detailed explanation on their usage.

!!! warning
    The function `constraints_capacity_installed` should not be changed.
    It is used for the inclusion of investments through `EnergyModelsInvestments`.
    It also has to be called, if you create a new function `constraints_capacity`.

```@docs
constraints_flow_in
constraints_flow_out
constraints_capacity
constraints_capacity_installed
constraints_level
constraints_level_aux
constraints_opex_var
constraints_opex_fixed
constraints_data
```

In addition, auxiliary functions are introduced for the calculation of the previous level of storage nodes.
These auxiliary functions provide the user with simple approaches for calculating the level balances.

```@docs
previous_level
previous_level_sp
```

## [Emission data](@id sec_lib_public_emdata)

Emission data are used to provide the individual nodes with potential emissions.
The approach is also explained on the page *[Data functions](@ref data_functions)*.

### `Emission` types

The thought process with `EmissionData` is to provide the user with options for each individual node to include emissions and potentially capture or not.
The individual types can be used for all included *[reference `Node`s](@ref sec_lib_public_refnodes)*, although capture is not possible for `Sink` nodes due to the lack of an output.

```@docs
EmissionsData
CaptureData
EmissionsEnergy
EmissionsProcess
CaptureEnergyEmissions
CaptureProcessEmissions
CaptureProcessEnergyEmissions
```

### Functions for accessing fields of `EmissionsData` types

The following functions are declared for accessing fields from a `EmissionsData` type.

!!! warning
    If you want to introduce new `EmissionsData` types, it is important that the functions `co2_capture` and `process_emissions` are either functional for your new types or you have to declare corresponding functions.
    The first approach can be achieved through using the same name for the respective fields.

```@docs
co2_capture
process_emissions
```

## Miscellaneous types/functions/macros

### `PreviousPeriods` and `CyclicPeriods`

`PreviousPeriods` is a type used to store information from the previous periods in an iteration loop through the application of the iterator [`withprev`](https://sintefore.github.io/TimeStruct.jl/stable/reference/api/#TimeStruct.withprev) of `TimeStruct`.

`CyclicPeriods` is used for storing the current and the last period.
The periods can either be either and `AbstractStrategicPeriod` or `AbstractRepresentativePeriod`.
In the former case, it is however not fully used as the last strategic period is not relevant for the level balances.

Both composite types allow only `EMB.NothingPeriod` types as input to the individual fields.

```@docs
PreviousPeriods
CyclicPeriods
EMB.NothingPeriod
```

The individual fields can be accessed through the following functions:

```@docs
strat_per
rep_per
op_per
last_per
current_per
```

### Macros for checking the input data

The macro `@assert_or_log` is an extension to the `@assert` macro to allow either for asserting the input data directly, or logging the errors in the input data.

```@docs
@assert_or_log
```

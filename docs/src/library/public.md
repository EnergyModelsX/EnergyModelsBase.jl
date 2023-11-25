# [Public interface](@id sec_lib_public)

## Resource

```@docs
Resource
ResourceCarrier
ResourceEmit
```

## Nodes

The following abstract types are inmplemented in the basis version.

```@docs
Source
NetworkNode
Sink
Storage
Availability
```

### Reference nodes

The following composite types are inmplemented in the basis version.

```@docs
RefSource
RefNetworkNode
RefSink
RefStorage
GenAvailability
```

### Legacy constructors

The following legacy constructors are implemented to avoid changing each individual model.
It is however uncertain, how long they will remain in the model.
To this end, it is suggest to adjust them

```@docs
RefNetwork
RefNetworkEmissions
RefStorageEmissions
```

## Links

```@docs
Linear
Link
Direct
```

## Model and data

```@docs
EnergyModel
OperationalModel
Data
EmptyData
```

## Functions for running the model

```@docs
create_model
run_model
```

## Functions for extending the model

The following functions are used for developing new nodes.
See the page [Creating a new node](@ref create_new_node) for a detailed explanation on how to create a new node.

```@docs
variables_node
create_node
```

## Constraint functions

The following functions can be used in new developed nodes.
See the page [Constraint functions](@ref constraint_functions) for a detailed explanation on their usage.

```@docs
constraints_flow_in
constraints_flow_out
constraints_capacity
constraints_capacity_installed
constraints_opex_var
constraints_opex_fixed
constraints_data
```

## [Emission data](@id sec_lib_public_emdata)

```@docs
EmissionsData
CaptureData
EmissionsEnergy
EmissionsProcess
CaptureEnergyEmissions
CaptureProcessEmissions
CaptureProcessEnergyEmissions
```

## Miscellaneous functions/macros

```@docs
@assert_or_log
```

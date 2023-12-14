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
constraints_level
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

## [Functions for accessing fields](@id sec_lib_public_fields)

Functions fo accessing `Node` fields:

```@docs
capacity
opex_var
opex_fixed
inputs
outputs
node_data
storage_resource
surplus_penalty
deficit_penalty
```

Functions for accessing `EmissionsData` fields:

```@docs
co2_capture
process_emissions
```

Functions for accessing `Link` fields:

```@docs
formulation
```

Functions for accessing `Resource` fields:

```@docs
co2_int
```

Functions for accessing `EnergyModel` fields:

```@docs
emission_limit
emission_price
co2_instance
```

Functions for identifying `Node`s:

```@docs
nodes_input
nodes_output
nodes_emissions
has_input
has_output
has_emissions
```

## Miscellaneous functions/macros

```@docs
@assert_or_log
```

# [Nodes](@id lib-pub-nodes)

`Node`s are used in `EnergyModelsBase` to convert `Resource`s.
They are coupled to the rest of the system through the *[Flow variables](@ref man-opt_var-flow)*.
Nodes are the key types for extending `EnergyModelsBase` through dispatch.
You can find an introduction of the different node types on the page *[Creating a new node](@ref how_to-create_node)*

## Index

```@index
Pages = ["nodes.md"]
```

## [Abstract `Node` types](@id lib-pub-nodes-abstract)

The following abstract node types are implemented in the `EnergyModelsBase`.
These abstract types are relevant for dispatching in individual functions.

```@docs
Source
NetworkNode
Sink
Storage
Availability
```

## [Reference node types](@id lib-pub-nodes-ref)

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

## [Storage behaviours](@id lib-pub-nodes-stor_behav)

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

## [Storage parameters](@id lib-pub-nodes-stor_par)

Storage parameters are used for describing different parameters for the individual capacities of a `Storage` node.
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

## [Functions for accessing fields of `Node` types](@id lib-pub-nodes-fun_field)

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
inputs(n::EnergyModelsBase.Node)
outputs(n::EnergyModelsBase.Node)
node_data
charge
level
discharge
storage_resource
surplus_penalty
deficit_penalty
```

## [Functions for identifying `Node`s](@id lib-pub-nodes-fun_identify)

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
has_emissions(n::EnergyModelsBase.Node)
has_charge
has_discharge
is_unidirectional(n::EnergyModelsBase.Node)
```

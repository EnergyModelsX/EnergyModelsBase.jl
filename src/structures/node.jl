""" `Node` as supertype for all technologies."""
abstract type Node end
Base.show(io::IO, n::Node) = print(io, "n_$(n.id)")

"""
`StorageBehavior` as supertype for individual storage behaviours.

Storage behaviour is used to identify how a storage node should behave within the individual
`TimeStructure`s of a strategic period.
"""
abstract type StorageBehavior end

"""
`Accumulating` as supertype for an accumulating storage level.

Accumulating storage behaviour implies that the change in the overall storage level in a
strategic period can be both positive or negative.

Examples for potential usage of `Accumulating` are CO₂ storages in which the CO₂ is
permanently stored or multi year hydropower magazines.
"""
abstract type Accumulating <: StorageBehavior end

"""
`Cyclic` as supertype for a cyclic storage level.

Cyclic storage behaviour implies that the change in the overall storage level in a strategic
period behaves cyclic.
"""
abstract type Cyclic <: StorageBehavior end

"""
    AccumulatingEmissions <: Accumulating

`StorageBehavior` which accumulates all inflow witin a strategic period.
`AccumulatingEmissions` allows as well to serve as a [`ResourceEmit`](@ref) emission point to
represent a soft constraint on storing the captured emissions.
"""
struct AccumulatingEmissions <: Accumulating end

"""
    CyclicRepresentative <: Cyclic

`StorageBehavior` in which cyclic behaviour is achieved within the lowest time structure
excluding operational times.

In the case of `TwoLevel{SimpleTimes}`, this approach is similar to `CyclicStrategic`.
In the case of `TwoLevel{RepresentativePeriods{SimpleTimes}}`, this approach differs from
`CyclicStrategic` as the cyclic constraint is enforeced within each representative period.
"""
struct CyclicRepresentative <: Cyclic end

"""
    CyclicStrategic <: Cyclic

`StorageBehavior` in which the the cyclic behaviour is achieved within a strategic period.
This implies that the initial level in individual representative periods can be different
when using `RepresentativePeriods`.
"""
struct CyclicStrategic <: Cyclic end

"""
`AbstractStorageParameters` as supertype for individual parameters for `Storage` nodes.

Storage parameters are used to provide the user the flexibility to include or not include
capacities and variable and fixed OPEX parameters for charging, the storage level, and
discharging.
"""
abstract type AbstractStorageParameters end

"""
    StorCapOpex <: AbstractStorageParameters

A storage parameter type for including a capacity as well as variable and fixed operational
expenditures.

# Fields
- **`capacity::TimeProfile`** is the installed capacity.
- **`opex_var::TimeProfile`** is the variable operating expense per energy unit.
- **`opex_fixed::TimeProfile`** is the fixed operating expense.
"""
struct StorCapOpex <: AbstractStorageParameters
    capacity::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
end

"""
    StorCap <: AbstractStorageParameters

A storage parameter type for including only a capacity. This implies that neither the usage
of the `Storage`, nor the installed capacity have a direct impact on the objective function.

# Fields
- **`capacity::TimeProfile`** is the installed capacity.
"""
struct StorCap <: AbstractStorageParameters
    capacity::TimeProfile
end

"""
    StorCap <: AbstractStorageParameters

A storage parameter type for including a capacity and variable operational expenditures.
This implies that the installed capacity has no direct impact on the objective function.

# Fields
- **`capacity::TimeProfile`** is the installed capacity.
- **`opex_var::TimeProfile`** is the variable operating expense per energy unit.
"""
struct StorCapOpexVar <: AbstractStorageParameters
    capacity::TimeProfile
    opex_var::TimeProfile
end

"""
    StorCapOpexFixed <: AbstractStorageParameters

A storage parameter type for including a capacity and fixed operational expenditures.
This implies that the installed capacity has no direct impact on the objective function.

# Fields
- **`capacity::TimeProfile`** is the installed capacity.
- **`opex_fixed::TimeProfile`** is the fixed operating expense.
"""
struct StorCapOpexFixed <: AbstractStorageParameters
    capacity::TimeProfile
    opex_fixed::TimeProfile
end

"""
    StorCap <: AbstractStorageParameters

A storage parameter type for including variable operational expenditures.
This implies that the charge or discharge rate do not have a capacity and the `Storage`
level can be used within a single `TimePeriod`.

This type can only be used for the fields `charge` and `discharge`.

# Fields
- **`opex_var::TimeProfile`** is the variable operating expense per energy unit.
"""
struct StorOpexVar <: AbstractStorageParameters
    opex_var::TimeProfile
end

"""
    UnionOpexFixed

Union for simpler dispatching for storage parameters that include fixed OPEX.
"""
UnionOpexFixed = Union{StorCapOpex,StorCapOpexFixed}

"""
    UnionOpexVar

Union for simpler dispatching for storage parameters that include variable OPEX.
"""
UnionOpexVar = Union{StorCapOpex,StorCapOpexVar,StorOpexVar}

"""
    UnionCapacity

Union for simpler dispatching for storage parameters that include a capacity.
"""
UnionCapacity = Union{StorCapOpex,StorCap,StorCapOpexVar,StorCapOpexFixed}

""" `Source` node with only output."""
abstract type Source <: Node end
""" `NetworkNode` node with both input and output."""
abstract type NetworkNode <: Node end
""" `Sink` node with only input."""
abstract type Sink <: Node end
""" `Storage` node with level."""
abstract type Storage{T<:StorageBehavior} <: NetworkNode end
""" `Availability` node as routing node."""
abstract type Availability <: NetworkNode end

"""
    RefSource <: Source

A reference `Source` node.
The reference `Source` node allows for a time varying capacity which is normalized to a
conversion value of 1 in the field `input`.
Note, that if you include investments, you can only use as `TimeProfile` a `FixedProfile`
or `StrategicProfile`.

# Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed capacity.
- **`opex_var::TimeProfile`** is the variable operating expense per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operating expense.
- **`output::Dict{<:Resource, <:Real}`** are the generated [`Resource`](@ref)s with
  conversion value `Real`.
- **`data::Vector{<:Data}`** is the additional data (e.g. for investments). The field `data`
  is conditional through usage of a constructor.
"""
struct RefSource <: Source
    id::Any
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    output::Dict{<:Resource,<:Real}
    data::Vector{<:Data}
end
function RefSource(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    output::Dict{<:Resource,<:Real},
)
    return RefSource(id, cap, opex_var, opex_fixed, output, Data[])
end

"""
    RefNetworkNode <: NetworkNode

A reference `NetworkNode` node.
The `RefNetworkNode` utilizes a linear, time independent conversion rate of the `input`
[`Resource`](@ref)s to the output [`Resource`](@ref)s, subject to the available capacity.
The capacity is hereby normalized to a conversion value of 1 in the fields `input` and
`output`.

# Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed capacity.
- **`opex_var::TimeProfile`** is the variable operating expense per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operating expense.
- **`input::Dict{<:Resource, <:Real}`** are the input [`Resource`](@ref)s with conversion
  value `Real`.
- **`output::Dict{<:Resource, <:Real}`** are the generated [`Resource`](@ref)s with
  conversion value `Real`.
- **`data::Vector{Data}`** is the additional data (e.g. for investments). The field `data`
  is conditional through usage of a constructor.
"""
struct RefNetworkNode <: NetworkNode
    id::Any
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    data::Vector{<:Data}
end
function RefNetworkNode(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
)
    return RefNetworkNode(id, cap, opex_var, opex_fixed, input, output, Data[])
end

"""
    GenAvailability <: Availability

A reference `Availability` node.
The reference `Availability` node solves the energy balance for all connected flows.

# Fields
- **`id`** is the name/identifier of the node.
- **`inputs::Vector{<:Resource}`** are the input [`Resource`](@ref)s.
- **`output::Vector{<:Resource}`** are the output [`Resource`](@ref)s.

A constructor is provided so that only a single array can be provided with the fields:
- **`id`** is the name/identifier of the node.
- **`𝒫::Vector{<:Resource}`** are the `[`Resource`](@ref)s.
"""
struct GenAvailability <: Availability
    id::Any
    input::Vector{<:Resource}
    output::Vector{<:Resource}
end
GenAvailability(id, 𝒫::Vector{<:Resource}) = GenAvailability(id, 𝒫, 𝒫)

"""
    RefStorage{T} <: Storage{T}

A reference `Storage` node.

This node is designed to store either a [`ResourceCarrier`](@ref) or a [`ResourceEmit`](@ref).
It is designed as a parametric type through the type parameter `T` to differentiate between
different cyclic behaviours. Note that the parameter `T` is only used for dispatching, but
does not carry any other information. Hence, it is simple to fast switch between different
[`StorageBehavior`](@ref)s.

The current implemented cyclic behaviours are [`CyclicRepresentative`](@ref),
[`CyclicStrategic`](@ref), and [`AccumulatingEmissions`](@ref).

# Fields
- **`id`** is the name/identifier of the node.
- **`charge::AbstractStorageParameters`** are the charging parameters of the `Storage` node.
  Depending on the chosen type, the charge parameters can include variable OPEX, fixed OPEX,
  and/or a capacity.
- **`level::AbstractStorageParameters`** are the level parameters of the `Storage` node.
  Depending on the chosen type, the charge parameters can include variable OPEX and/or fixed OPEX.
- **`stor_res::Resource`** is the stored [`Resource`](@ref).
- **`input::Dict{<:Resource, <:Real}`** are the input [`Resource`](@ref)s with conversion
  value `Real`.
- **`output::Dict{<:Resource, <:Real}`** are the generated [`Resource`](@ref)s with conversion
  value `Real`. Only relevant for linking and the stored [`Resource`](@ref) as the output
  value is not utilized in the calculations.
- **`data::Vector{<:Data}`** is the additional data (e.g. for investments). The field `data`
  is conditional through usage of a constructor.
"""
struct RefStorage{T} <: Storage{T}
    id::Any
    charge::AbstractStorageParameters
    level::UnionCapacity
    stor_res::Resource
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    data::Vector{<:Data}
end

function RefStorage{T}(
    id,
    charge::AbstractStorageParameters,
    level::UnionCapacity,
    stor_res::Resource,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
) where {T<:StorageBehavior}
    return RefStorage{T}(id, charge, level, stor_res, input, output, Data[])
end

"""
    RefSink <: Sink

A reference `Sink` node. This node corresponds to a demand given by the field `cap`.
The penalties introduced in the field `penalty` affect the variable OPEX for both a surplus
and deficit.

# Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the Demand.
- **`penalty::Dict{Any, TimeProfile}`** are penalties for surplus or deficits. Requires the
  fields `:surplus` and `:deficit`.
- **`input::Dict{<:Resource, <:Real}`** are the input [`Resource`](@ref)s with conversion value `Real`.
- **`data::Vector{<:Data}`** is the additional data (e.g. for investments). The field `data`
  is conditional through usage of a constructor.
"""
struct RefSink <: Sink
    id::Any
    cap::TimeProfile
    penalty::Dict{Symbol,<:TimeProfile}
    input::Dict{<:Resource,<:Real}
    data::Vector{<:Data}
end
function RefSink(
    id,
    cap::TimeProfile,
    penalty::Dict{<:Any,<:TimeProfile},
    input::Dict{<:Resource,<:Real},
)
    return RefSink(id, cap, penalty, input, Data[])
end

"""
    is_source(n::Node)

Checks, whether node `n` is a `Source` node
"""
is_source(n::Node) = false
is_source(n::Source) = true

"""
    is_network_node(n::Node)

Checks, whether node `n` is a `NetworkNode` node
"""
is_network_node(n::Node) = false
is_network_node(n::NetworkNode) = true

"""
    is_storage(n::Node)

Checks, whether node `n` is a `Storage` node
"""
is_storage(n::Node) = false
is_storage(n::Storage) = true

"""
    is_sink(n::Node)

Checks, whether node `n` is a `Sink` node
"""
is_sink(n::Node) = false
is_sink(n::Sink) = true

"""
    has_emissions(n::Node)

Checks whether the Node `n` has emissions.
"""
has_emissions(n::Node) = any(typeof(data) <: EmissionsData for data ∈ n.data)
has_emissions(n::Availability) = false
has_emissions(n::RefStorage{AccumulatingEmissions}) = true

"""
    has_emissions(𝒩::Array{<:Node})

Returns nodes that have emission data for a given Array `::Array{<:Node}`.
"""
nodes_emissions(𝒩::Array{<:Node}) = filter(has_emissions, 𝒩)

"""
    nodes_sub(𝒩::Array{<:Node}, sub)

Returns nodes that are of type `sub` for a given Array `𝒩::Array{<:Node}`.
"""
nodes_sub(𝒩::Array{<:Node}, sub = NetworkNode) = filter(x -> isa(x, sub), 𝒩)

"""
    nodes_not_sub(𝒩::Array{<:Node}, sub)

Returns nodes that are not of type `sub` for a given Array `𝒩::Array{<:Node}`.
"""
nodes_not_sub(𝒩::Array{<:Node}, sub = NetworkNode) = filter(x -> ~isa(x, sub), 𝒩)

"""
    nodes_not_av(𝒩::Array{<:Node})

Returns nodes that are not `Availability` nodes for a given Array `𝒩::Array{<:Node}`.
"""
nodes_not_av(𝒩::Array{<:Node}) = filter(x -> ~isa(x, Availability), 𝒩)

"""
    nodes_input(𝒩::Array{<:Node}, sub)

Returns nodes that have an input, i.e., `Sink` and `NetworkNode` nodes.
"""
nodes_input(𝒩::Array{<:Node}) = filter(has_input, 𝒩)

"""
    has_input(n::Node)

Returns logic whether the node is an input node, i.e., `Sink` and `NetworkNode` nodes.
"""
has_input(n::Node) = true
has_input(n::Source) = false

"""
    nodes_output(𝒩::Array{<:Node})

Returns nodes that have an output, i.e., `Source` and `NetworkNode` nodes.
"""
nodes_output(𝒩::Array{<:Node}) = filter(has_output, 𝒩)

"""
    has_output(n::Node)

Returns logic whether the node is an output node, i.e., `Source` and `NetworkNode` nodes.
"""
has_output(n::Node) = true
has_output(n::Sink) = false

"""
    has_charge(n::Storage)

Returns logic whether the node has a `charge` field allowing for restrictions and/or costs
on the (installed) charging rate.
"""
has_charge(n::Storage) = hasfield(typeof(n), :charge)

"""
    charge(n::Storage)

Returns the parameter type of the `charge` field of the node. If the node has no field
`charge`, it returns `nothing`.
"""
charge(n::Storage) = has_charge(n) ? n.charge : nothing

"""
    has_charge_cap(n::Storage)

Returns logic whether the node has a `charge` capacity.
"""
has_charge_cap(n::Storage) = has_charge(n) && isa(charge(n), UnionCapacity)

"""
    has_charge_OPEX_fixed(n::Storage)

Returns logic whether the node has a `charge` fixed OPEX contribution.
"""
has_charge_OPEX_fixed(n::Storage) =
    has_charge(n) && isa(charge(n), UnionOpexFixed)

"""
    has_charge_OPEX_var(n::Storage)

Returns logic whether the node has a `charge` variable OPEX contribution.
"""
has_charge_OPEX_var(n::Storage) =
    has_charge(n) && isa(charge(n), UnionOpexVar)

"""
    has_discharge(n::Storage)

Returns logic whether the node has a `discharge` field allowing for restrictions and/or costs
on the (installed) discharging rate.
"""
has_discharge(n::Storage) = hasfield(typeof(n), :discharge)

"""
    discharge(n::Storage)

Returns the parameter type of the `discharge` field of the node. If the node has no field
`discharge`, it returns `nothing`.
"""
discharge(n::Storage) = has_discharge(n) ? n.discharge : nothing

"""
    has_discharge_cap(n::Storage)

Returns logic whether the node has a `discharge` capacity.
"""
has_discharge_cap(n::Storage) =
    has_discharge(n) && isa(discharge(n), UnionCapacity)

"""
    has_discharge_OPEX_fixed(n::Storage)

Returns logic whether the node has a `discharge` fixed OPEX contribution.
"""
has_discharge_OPEX_fixed(n::Storage) =
    has_discharge(n) && isa(discharge(n), UnionOpexFixed)

"""
    has_discharge_OPEX_var(n::Storage)

Returns logic whether the node has a `discharge` variable OPEX contribution.
"""
has_discharge_OPEX_var(n::Storage) =
    has_discharge(n) && isa(discharge(n), UnionOpexVar)

"""
    level(n::Storage)

Returns the parameter type of the `level` field of the node.
"""
level(n::Storage) = n.level

"""
    has_level_OPEX_fixed(n::Storage)

Returns logic whether the node has a `level` fixed OPEX contribution.
"""
has_level_OPEX_fixed(n::Storage) = isa(level(n), UnionOpexFixed)

"""
    has_level_OPEX_var(n::Storage)

Returns logic whether the node has a `level` variable OPEX contribution.
"""
has_level_OPEX_var(n::Storage) = isa(level(n), UnionOpexVar)

"""
    capacity(n::Node)

Returns the capacity of a node `n` as `TimeProfile`. The capacity is not directly defined
for `Storage` nodes. Instead, it is necessary to call the function on the respective
field, see [`capacity(stor_par::AbstractStorageParameters)`](@ref).
"""
capacity(n::Node) = n.cap
"""
    capacity(stor_par::AbstractStorageParameters)

Returns the capacity of storage parameter `stor_par` as `TimeProfile`.
The individual storage parameters of a `Storage` node can be accessed through the functions
[`charge(n)`](@ref), [`level(n)`](@ref), and [`discharge(n)`](@ref).
"""
capacity(stor_par::AbstractStorageParameters) = stor_par.capacity

"""
    capacity(n::Node, t)

Returns the capacity of a node `n` at operational period `t`. The capacity is not directly
defined for `Storage` nodes. Instead, it is necessary to call the function on the respective
field, see [`capacity(stor_par::AbstractStorageParameters, t)`](@ref).
"""
capacity(n::Node, t) = n.cap[t]
"""
    capacity(stor_par::AbstractStorageParameters, t)

Returns the capacity of storage parameter `stor_par` at operational period `t`.
The individual storage parameters of a `Storage` node can be accessed through the functions
[`charge(n)`](@ref), [`level(n)`](@ref), and [`discharge(n)`](@ref).
"""
capacity(stor_par::AbstractStorageParameters, t) = stor_par.capacity[t]

"""
    inputs(n::Node)

Returns the input resources of a node `n`. These resources are specified via the field
`input`.
"""
inputs(n::Node) = collect(keys(n.input))
inputs(n::Availability) = n.input
inputs(n::Source) = []

"""
    inputs(n::Node, p::Resource)

Returns the value of an input resource `p` of a node `n`.
"""
inputs(n::Node, p::Resource) = n.input[p]
inputs(n::Availability, p::Resource) = 1
inputs(n::Source, p::Resource) = nothing

"""
    outputs(n::Node)

Returns the output resources of a node `n`. These resources are specified via the field
`output`.
"""
outputs(n::Node) = collect(keys(n.output))
outputs(n::Availability) = n.output
outputs(n::Sink) = []

"""
    outputs(n::Node, p::Resource)

Returns the value of an output resource `p` of a node `n`.
"""
outputs(n::Node, p::Resource) = n.output[p]
outputs(n::Availability, p::Resource) = 1
outputs(n::Sink, p::Resource) = nothing

"""
    node_data(n::Node)

Returns the `Data` array of node `n`.
"""
node_data(n::Node) = n.data
node_data(n::Availability) = []

"""
    storage_resource(n::Storage)

Returns the storage resource of `Storage` node `n`.
"""
storage_resource(n::Storage) = n.stor_res

"""
    opex_var(n::Node)

Returns the variable OPEX of a node `n` as `TimeProfile`. The variable OPEX is not directly
defined for `Storage` nodes. Instead, it is necessary to call the function on the respective
field, see [`opex_var(stor_par::AbstractStorageParameters)`](@ref).
"""
opex_var(n::Node) = n.opex_var
"""
    opex_var(stor_par::UnionOpexVar)

Returns the variable OPEX of storage parameter `stor_par` as `TimeProfile`.
The individual storage parameters of a `Storage` node can be accessed through the functions
[`charge(n)`](@ref), [`level(n)`](@ref), and [`discharge(n)`](@ref).
"""
opex_var(stor_par::UnionOpexVar) = stor_par.opex_var
"""
    opex_var(n::Node, t)

Returns the variable OPEX of a node `n` in operational period `t`. The variable OPEX is not
directly defined for `Storage` nodes. Instead, it is necessary to call the function on the
respective field, see [`opex_var(stor_par::AbstractStorageParameters, t)`](@ref).
"""
opex_var(n::Node, t) = n.opex_var[t]
"""
    opex_var(stor_par::UnionOpexVar, t)

Returns the variable OPEX of storage parameter `stor_par` at operational period `t`.
The individual storage parameters of a `Storage` node can be accessed through the functions
[`charge(n)`](@ref), [`level(n)`](@ref), and [`discharge(n)`](@ref).
"""
opex_var(stor_par::UnionOpexVar, t) = stor_par.opex_var[t]

"""
    opex_fixed(n::Node)

Returns the fixed OPEX of a node `n` as `TimeProfile`. The fixed OPEX is not directly
defined for `Storage` nodes. Instead, it is necessary to call the function on the respective
field, see [`opex_fixed(stor_par::AbstractStorageParameters)`](@ref).
"""
opex_fixed(n::Node) = n.opex_fixed
"""
    opex_fixed(stor_par::UnionOpexFixed)

Returns the fixed OPEX of storage parameter `stor_par` as `TimeProfile`.
The individual storage parameters of a `Storage` node can be accessed through the functions
[`charge(n)`](@ref), [`level(n)`](@ref), and [`discharge(n)`](@ref).
"""
opex_fixed(stor_par::UnionOpexFixed) = stor_par.opex_fixed
"""
    opex_fixed(n::Node, t_inv)

Returns the fixed OPEX of a node `n` at strategic period `t_inv`. The fixed OPEX is not
directly defined for `Storage` nodes. Instead, it is necessary to call the function on the
respective field, see [`opex_fixed(stor_par::AbstractStorageParameters, t)`](@ref).
"""
opex_fixed(n::Node, t_inv) = n.opex_fixed[t_inv]
"""
    opex_fixed(stor_par::UnionOpexFixed, t)

Returns the fixed OPEX of storage parameter `stor_par` at operational period `t`.
The individual storage parameters of a `Storage` node can be accessed through the functions
[`charge(n)`](@ref), [`level(n)`](@ref), and [`discharge(n)`](@ref).
"""
opex_fixed(stor_par::UnionOpexFixed, t_inv) = stor_par.opex_fixed[t_inv]

"""
    surplus_penalty(n::Sink)
Returns the surplus penalty of sink `n` as `TimeProfile`.
"""
surplus_penalty(n::Sink) = n.penalty[:surplus]
"""
    surplus_penalty(n::Sink, t)
Returns the surplus penalty of sink `n` at operational period `t`
"""
surplus_penalty(n::Sink, t) = n.penalty[:surplus][t]

"""
    deficit_penalty(n::Sink)
Returns the deficit penalty of sink `n` as `TimeProfile`.
"""
deficit_penalty(n::Sink) = n.penalty[:deficit]
"""
    deficit_penalty(n::Sink, t)
Returns the deficit penalty of sink `n` at operational period `t`
"""
deficit_penalty(n::Sink, t) = n.penalty[:deficit][t]

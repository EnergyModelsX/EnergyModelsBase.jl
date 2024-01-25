""" `Node` as supertype for all technologies."""
abstract type Node end
Base.show(io::IO, n::Node) = print(io, "n_$(n.id)")

""" `Source` node with only output."""
abstract type Source <: Node end
""" `NetworkNode` node with both input and output."""
abstract type NetworkNode <: Node end
""" `Sink` node with only input."""
abstract type Sink <: Node end
""" `Storage` node with level."""
abstract type Storage <: NetworkNode end
""" `Availability` node as routing node."""
abstract type Availability <: NetworkNode end

""" A reference `Source` node.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`cap::TimeProfile`** is the installed capacity.\n
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`.\n
- **`data::Array{Data}`** is the additional data (e.g. for investments).

"""
struct RefSource <: Source
    id
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    output::Dict{Resource, Real}
    data::Array{Data}
end
function RefSource(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    output::Dict{<:Resource,<:Real},
    )
    return RefSource(id, cap, opex_var, opex_fixed, output, [])
end

""" A reference `NetworkNode` node.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`cap::TimeProfile`** is the installed capacity.\n
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.\n
- **`output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`.\n
- **`data::Array{Data}`** is the additional data (e.g. for investments).
"""
struct RefNetworkNode <: NetworkNode
    id
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{Resource, Real}
    output::Dict{Resource, Real}
    data::Array{Data}
end

""" A reference `Availability` node.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`inputs::Array{Resource}`** are the input `Resource`s.\n
- **`output::Array{Resource}`** are the output `Resource`s.\n

A constructor is provided so that only a single array can be provided with the fields:
- **`id`** is the name/identifier of the node.\n
- **`𝒫::Array{Resource}`** are the `Resource`s.\n
"""
struct GenAvailability <: Availability
    id
    input::Array{Resource}
    output::Array{Resource}
end
GenAvailability(id, 𝒫::Array{Resource}) = GenAvailability(id, 𝒫, 𝒫)

""" A reference `Storage` node.

This node is designed to store either a `ResourceCarrier` or a `ResourceEmit`.
It is designed as a composite type to automatically distinguish between these two.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`rate_cap::TimeProfile`** is the installed rate capacity, that is e.g. power or mass flow.\n
- **`stor_cap::TimeProfile`** is the installed storage capacity, that is e.g. energy or mass.\n
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit stored.\n
- **`opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`stor_res::Resource`** is the stored `Resource`.\n
- **`input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.
- **`output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`. \
Only relevant for linking and the stored `Resource`.\n
- **`data::Array{Data}`** is the additional data (e.g. for investments).
"""
struct RefStorage{T} <: Storage
    id
    rate_cap::TimeProfile
    stor_cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    stor_res::T
    input::Dict{<:Resource, <:Real}
    output::Dict{<:Resource, <:Real}
    data::Array{<:Data}
end

""" A reference `Sink` node.

This node corresponds to a demand given by the field `cap`.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`cap::TimeProfile`** is the Demand.\n
- **`penalty::Dict{Any, TimeProfile}`** are penalties for surplus or deficits. \
Requires the fields `:surplus` and `:deficit`.\n
- **`input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.\n
- **`data::Array{Data}`** is the additional data (e.g. for investments).
"""
struct RefSink <: Sink
    id
    cap::TimeProfile
    penalty::Dict{Any, TimeProfile}
    input::Dict{Resource, Real}
    data::Array{Data}
end
function RefSink(
    id,
    cap::TimeProfile,
    penalty::Dict{<:Any,<:TimeProfile},
    input::Dict{<:Resource,<:Real},
    )
    return RefSink(id, cap, penalty, input, [])
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
    nodes_sub(𝒩::Array{Node}, sub/subs)

Return nodes that are of type sub/subs for a given Array `::Array{Node}`.
"""
node_sub(𝒩::Array{Node}, sub = NetworkNode) = 𝒩[findall(x -> isa(x, sub), 𝒩)]

"""
    has_emissions(n::Node)

Checks whether the Node `n` has emissions.
"""
has_emissions(n::Node) = any(typeof(data) <: EmissionsData for data ∈ n.data)
has_emissions(n::Availability) = false
has_emissions(n::RefStorage{<:ResourceEmit}) = true

"""
    has_emissions(𝒩::Array{Node})

Return nodes that have emission data for a given Array `::Array{Node}`.
"""
nodes_emissions(𝒩::Array{Node}) = filter(has_emissions, 𝒩)

"""
    nodes_not_sub(𝒩::Array{Node}, sub)

Return nodes that are not of type `sub` for a given Array `::Array{Node}`.
"""
nodes_not_sub(𝒩::Array{Node}, sub = NetworkNode) = filter(x -> ~isa(x, sub), 𝒩)

"""
    nodes_not_av(𝒩::Array{Node})

Return nodes that are not `Availability` nodes for a given Array `::Array{Node}`.
"""
nodes_not_av(𝒩::Array{Node}) = filter(x -> ~isa(x, Availability), 𝒩)

# function node_sub(𝒩::Array{Node}, subs...)
#     return 𝒩[findall(x -> sum(isa(x, sub) for sub in subs) >= 1, 𝒩)]
# end

"""
    nodes_input(𝒩::Array{Node}, sub)

Return nodes that have an input, i.e., `Sink` and `NetworkNode` nodes.
"""
nodes_input(𝒩::Array{<:Node}) = filter(has_input, 𝒩)

"""
    has_input(n::Node)

Return logic whether the node is an input node, i.e., `Sink` and `NetworkNode` nodes.
"""
has_input(n::Node) = true
has_input(n::Source) = false

"""
    nodes_output(𝒩::Array{Node})

Return nodes that have an output, i.e., `Source` and `NetworkNode` nodes.
"""
nodes_output(𝒩::Array{<:Node}) = filter(has_output, 𝒩)

"""
    has_output(n::Node)

Return logic whether the node is an output node, i.e., `Source` and `NetworkNode` nodes.
"""
has_output(n::Node) = true
has_output(n::Sink) = false

"""
    capacity(n)

Returns the capacity of a node `n` as `TimeProfile`. In the case of a `Storage` node,
the capacity is returned as `NamedTuple` with the fields `level` and `rate`.
"""
capacity(n::Node) = n.cap
capacity(n::Storage) = (level=n.stor_cap, rate=n.rate_cap)

"""
    capacity(n, t)

Returns the capacity of a node `n` at time period `t`. In the case of a `Storage` node,
the capacity is returned as `NamedTuple` with the fields `level` and `rate`.
"""
capacity(n::Node, t) = n.cap[t]
capacity(n::Storage, t) = (level=n.stor_cap[t], rate=n.rate_cap[t])

"""
    inputs(n)

Returns the input resources of a node `n`. These resources are specified via the field
`input`.
"""
inputs(n::Node) = collect(keys(n.input))
inputs(n::Availability) = n.input
inputs(n::Source) = []

"""
    inputs(n, p)

Returns the value of an input resource `p` of a node `n`.
"""
inputs(n::Node, p) = n.input[p]
inputs(n::Source, p) = nothing

"""
    outputs(n)

Returns the output resources of a node `n`. These resources are specified via the field
`output`.
"""
outputs(n::Node) = collect(keys(n.output))
outputs(n::Availability) = n.output

"""
    outputs(n, p)

Returns the value of an output resource `p` of a node `n`.
"""
outputs(n::Node, p) = n.output[p]

"""
    node_data(n::Node)

Returns the `Data` array of node `n`.
"""
node_data(n::Node) = n.data

"""
    storage_resource(n::Storage)

Returns the storage resource of `Storage` node `n`.
"""
storage_resource(n::Storage) = n.stor_res

"""
    opex_var(n)

Returns the variable OPEX of a node `n` as `TimeProfile`.
"""
opex_var(n::Node) = n.opex_var
"""
    opex_var(n, t)

Returns the variable OPEX of a node `n` at time period `t`
"""
opex_var(n::Node, t) = n.opex_var[t]

"""
    opex_fixed(n)

Returns the fixed OPEX of a node `n` as `TimeProfile`.
"""
opex_fixed(n::Node) = n.opex_fixed
"""
    opex_fixed(n, t)

Returns the fixed OPEX of a node `n` at time period `t`
"""
opex_fixed(n::Node, t) = n.opex_fixed[t]

"""
    surplus_penalty(n::Sink)
Returns the surplus penalty of sink `n` as `TimeProfile`.
"""
surplus_penalty(n::Sink) = n.penalty[:surplus]
"""
    surplus_penalty(n::Sink, t)
Returns the surplus penalty of sink `n` at time period `t`
"""
surplus_penalty(n::Sink, t) = n.penalty[:surplus][t]

"""
    deficit_penalty(n::Sink)
Returns the deficit penalty of sink `n` as `TimeProfile`.
"""
deficit_penalty(n::Sink) = n.penalty[:deficit]
"""
    deficit_penalty(n::Sink, t)
Returns the deficit penalty of sink `n` at time period `t`
"""
deficit_penalty(n::Sink, t) = n.penalty[:deficit][t]

"""
Resources that can be transported and converted.

# Fields
- **`id`** is the name/identifyer of the resource.\n
- **`co2_int::T`** is the the CO2 intensity.\n

"""
abstract type Resource end
Base.show(io::IO, r::Resource) = print(io, "$(r.id)")

"""
Resources that can can be emitted (e.g., CO2, CH4, NOx).

# Fields
- **`id`** is the name/identifyer of the resource.\n
- **`co2_int::T`** is the the CO2 intensity.\n

"""
struct ResourceEmit{T<:Real} <: Resource
    id
    co2_int::T
end

"""
General resources.
"""
struct ResourceCarrier{T<:Real} <: Resource
    id
    co2_int::T
end

"""
    co2_int(p::Resource)

Returns the CO2 intensity of resource `p`
"""
co2_int(p::Resource) = p.co2_int

"""
    res_sub(𝒫::Array{<:Resource}, sub = ResourceEmit)

Return resources that are of type `sub` for a given Array `::Array{Resource}`.
"""
res_sub(𝒫::Array{<:Resource}, sub = ResourceEmit) = 𝒫[findall(x -> isa(x, sub), 𝒫)]

"""
    res_not(𝒩::Array{<:Resource}, res_inst)

Return all resources that are not `res_inst` for
 - a given array `::Array{<:Resource}`.\
 The output is in this case an `Array{<:Resource}`
 - a given dictionary `::Dict`.\
The output is in this case a dictionary `Dict` with the correct fields
"""
res_not(𝒫::Array{<:Resource}, res_inst::Resource) = 𝒫[findall(x -> x!=res_inst, 𝒫)]
res_not(𝒫::Dict, res_inst::Resource) =  Dict(k => v for (k,v) ∈ 𝒫 if k != res_inst)

"""
    res_em(𝒫::Array{<:Resource})

Returns all emission resources for a
- a given array `::Array{<:Resource}`.\
The output is in this case an `Array{<:Resource}`
- a given dictionary `::Dict`.\
The output is in this case a dictionary `Dict` with the correct fields
"""
res_em(𝒫::Array{<:Resource}) = 𝒫[findall(x -> isa(x, ResourceEmit), 𝒫)]
res_em(𝒫::Dict) =  Dict(k => v for (k,v) ∈ 𝒫 if isa(k, ResourceEmit))

""" Abstract type used to define concrete struct containing the package specific elements
to add to the composite type defined in this package."""
abstract type Data end
""" Empty composite type for `Data`"""
struct EmptyData <: Data end

"""
    EmissionsData <: Data end

Abstract type for `EmissionsData` can be used to dispatch on different type of
capture configurations.

In general, the different types require the following input:
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`co2_capture::Real`** is the CO2 capture rate.\n

# Types
- **`CaptureProcessEnergyEmissions`**: Capture both the process emissions and the energy usage \
related emissions.\n
- **`CaptureProcessEmissions`**: Capture the process emissions, but not the energy usage related \
emissions.\n
- **`CaptureEnergyEmissions`**: Capture the energy usage related emissions, but not the process \
emissions. Does not require `emissions` as input.\n
- **`EmissionsProcess`**: No capture, but process emissions are present. Does not require \
`co2_capture` as input, but will ignore it, if provided.\n
"""

""" `EmissionsData` as supertype for all `Data` types for emissions."""
abstract type EmissionsData <: Data end
""" `CaptureData` as supertype for all `EmissionsData` that include CO2 capture."""
abstract type CaptureData <: EmissionsData end

"""
Capture both the process emissions and the energy usage related emissions.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`co2_capture::Real`** is the CO2 capture rate.
"""
struct CaptureProcessEnergyEmissions <: CaptureData
    emissions::Dict{ResourceEmit,Real}
    co2_capture::Real
end
"""
Capture the process emissions, but not the energy usage related emissions.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`co2_capture::Real`** is the CO2 capture rate.
"""
struct CaptureProcessEmissions <: CaptureData
    emissions::Dict{ResourceEmit,Real}
    co2_capture::Real
end
"""
Capture the energy usage related emissions, but not the process emissions.
Does not require `emissions` as input, but can be supplied.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`co2_capture::Real`** is the CO2 capture rate.
"""
struct CaptureEnergyEmissions <: CaptureData
    emissions::Dict{ResourceEmit,Real}
    co2_capture::Real
end
CaptureEnergyEmissions(co2_capture::Real) = CaptureEnergyEmissions(Dict(), co2_capture)
"""
No capture, but process emissions are present. Does not require `co2_capture` as input,
but accepts it and will ignore it, if provided.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
"""
struct EmissionsProcess <: EmissionsData
    emissions::Dict{ResourceEmit,Real}
end
EmissionsProcess(emissions::Dict{ResourceEmit,Real}, _) = EmissionsProcess(emissions)
EmissionsProcess() = EmissionsProcess(Dict())
"""
No capture, no process emissions are present. Does not require `co2_capture` or `emissions`
as input, but accepts it and will ignore it, if provided.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
"""
struct EmissionsEnergy <: EmissionsData
end
EmissionsEnergy(_, _) = EmissionsEnergy()
EmissionsEnergy(_) = EmissionsEnergy()

co2_capture(data::CaptureData) = data.co2_capture
process_emissions(data::EmissionsData, p) = haskey(data.emissions, p) ? data.emissions[p] : 0
process_emissions(data::EmissionsData) = collect(keys(data))

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
- **`output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`..\n
- **`data::Array{Data}`** is the additional data (e.g. for investments).\n
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per energy unit produced.

"""
struct RefSource <: Source
    id
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    output::Dict{Resource, Real}
    data::Array{Data}
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
- **`input::Array{<:Resource}`** are the input `Resource`s with conversion value `Real`.
The latter are not relevant but included for consistency with other formulations.\n
- **`output::Array{<:Resource}`** are the generated `Resource`s with conversion value `Real`.
The latter are not relevant but included for consistency with other formulations.\n

"""
struct GenAvailability <: Availability
    id
    input::Array{Resource}
    output::Array{Resource}
end
GenAvailability(id, 𝒫::Array{Resource}) =
    GenAvailability(id, 𝒫, 𝒫)

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
- **`output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`.
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
- **`penalty::Dict{Any, TimeProfile}`** are penalties for surplus or deficits.
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

"""
    node_sub(𝒩::Array{Node}, sub/subs)

Return nodes that are of type sub/subs for a given Array `::Array{Node}`.
"""
node_sub(𝒩::Array{Node}, sub = NetworkNode) = 𝒩[findall(x -> isa(x, sub), 𝒩)]

"""
    node_emissions(𝒩::Array{Node})

Return nodes that have emission data for a given Array `::Array{Node}`.
"""
node_emissions(𝒩::Array{Node}) = 𝒩[findall(x -> has_emissions(x), 𝒩)]
has_emissions(n::Node) = any(typeof(data) <: EmissionsData for data ∈ n.data)
has_emissions(n::Availability) = false
has_emissions(n::RefStorage{<:ResourceEmit}) = true

"""
    node_not_sub(𝒩::Array{Node}, sub)

Return nodes that are not of type `sub` for a given Array `::Array{Node}`.
"""
node_not_sub(𝒩::Array{Node}, sub = NetworkNode) = 𝒩[findall(x -> ~isa(x, sub), 𝒩)]

"""
    node_not_av(𝒩::Array{Node})

Return nodes that are not `Availability` nodes for a given Array `::Array{Node}`.
"""
node_not_av(𝒩::Array{Node}) = 𝒩[findall(x -> ~isa(x, Availability), 𝒩)]

# function node_sub(𝒩::Array{Node}, subs...)
#     return 𝒩[findall(x -> sum(isa(x, sub) for sub in subs) >= 1, 𝒩)]
# end

"""
    node_not_sub(𝒩::Array{Node}, sub)

Return nodes that have an input, i.e., `Sink` and `NetworkNode` nodes.
"""
nodes_input(𝒩::Array{<:Node}) = 𝒩[findall(x -> ~isa(x, Source), 𝒩)]
"""
    node_input(n::Node)

Return logic whether the node is an input node.
"""
node_input(n::Node) = ~isa(n, Source)

"""
    nodes_output(𝒩::Array{Node})

Return nodes that have an input, i.e., `Source` and `NetworkNode` nodes.
"""
nodes_output(𝒩::Array{<:Node}) = 𝒩[findall(x -> ~isa(x, Sink), 𝒩)]
"""
    node_output(n::Node)

Return logic whether the node is an output node.
"""
node_output(n::Node) = ~isa(n, Sink)

"""
    capacity(n)

Returns the input resources of a node `n`.
"""
capacity(n::Node) = n.cap
capacity(n::Storage) = (level=n.stor_cap, rate=n.rate_cap)

"""
    input(n)

Returns the input resources of a node `n`.
"""
input(n::Node) = collect(keys(n.input))
input(n::Availability) = n.input
input(n::Source) = []

"""
    input(n, p)

Returns the value of an input resource `p` of a node `n`.
"""
input(n::Node, p) = n.input[p]
input(n::Source, p) = nothing

"""
    output(n)

Returns the output resources of a node `n`.
"""
output(n::Node) = collect(keys(n.output))
output(n::Availability) = n.output

"""
    output(n, p)

Returns the value of an output resource `p` of a node `n`.
"""
output(n::Node, p) = n.output[p]

"""
    node_data(n::Node)

Return logic whether the node is an output node.
"""
node_data(n::Node) = n.data

"""
    storage_resource(n::Storage)

Returns the storage resource of `Storage` node `n`.
"""
storage_resource(n::Storage) = n.stor_res

"""
    process_emissions(n::Node, p)

Returns the process emissions of node `n` for resource `p`.
"""
process_emissions(n::Node, p) = n.emissions[p]

"""
    process_emissions(n::Node, p)

Returns the process emissions of node `n` for resource `p`.
"""
co2_capture(n::Node) = n.co2_capture

"""
    opex_var(n, t)

Returns the variable OPEX of a node `n` at time period `t`
"""
opex_var(n::Node, t) = n.opex_var[t]

"""
    opex_fixed(n, t)

Returns the variable OPEX of a node `n` at time period `t`
"""
opex_fixed(n::Node, t) = n.opex_fixed[t]

"""
    surplus(n::Sink, t)
Returns the surplus of sink `n` at time period `t`
"""
surplus(n::Sink, t) = n.penalty[:surplus][t]

"""
    deficit(n::Sink, t)
Returns the deficit of sink `n` at time period `t`
"""
deficit(n::Sink, t) = n.penalty[:deficit][t]

""" Declaration of the general type for formulation of links."""
abstract type Formulation end

""" Linear `Link`, that is input equals output."""
struct Linear <: Formulation end

""" Declaration of the general type for links connecting nodes."""
abstract type Link end
Base.show(io::IO, l::Link) = print(io, "l_$(l.from)-$(l.to)")

""" `Direct <: Link`

A direct link between two nodes.

# Fields
- **`id`** is the name/identifier of the link.\n
- **`from::Node`** is node from which there is flow into the link.\n
- **`to::Node`** is node to which there is flow out of the link.\n
- **`formulation::Formulation`** is the used formulation of links. If not specified,
a `Linear` link is assumed\n

"""
struct Direct <: Link
    id
    from::Node
    to::Node
    formulation::Formulation
end
Direct(id, from::Node, to::Node) = Direct(id, from, to, Linear())


"""
    link_sub(ℒ, n::Node)

Return connected links for a given node  `::Array{Link}`.
"""
function link_sub(ℒ, n::Node)
    return [ℒ[findall(x -> x.from == n, ℒ)],
            ℒ[findall(x -> x.to   == n, ℒ)]]
end

"""
    link_res(l::Link)

Return the resources transported for a given link l.
"""
link_res(l::Link) = intersect(input(l.to), output(l.from))

"""
    formulation(l::Link)

Return the formulation of a Link ´l´.
"""
formulation(l::Link) = l.formulation

""" Abstract type for differentation between types of models (investment, operational, ...)."""
abstract type EnergyModel end

"""
Operational Energy Model without investments.

# Fields
- **`emission_limit`** is a dictionary with individual emission limits as `TimeProfile` for each
emission resource `ResourceEmit`.\n
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO2.\n
"""
struct OperationalModel <: EnergyModel
    emission_limit::Dict{ResourceEmit, TimeProfile}
    co2_instance::ResourceEmit
end

emission_limit(model, p, t) = model.emission_limit[p][t]
co2_instance(model) = model.co2_instance

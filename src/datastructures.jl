"""
Resources that can be transported and converted. 

# Fields
- **`id`** is the name/identifyer of the resource.\n
- **`CO2_int::T`** is the the CO2 intensity.\n

"""
abstract type Resource end
Base.show(io::IO, r::Resource) = print(io, "$(r.id)")

"""
Resources that can can be emitted (e.g., CO2, CH4, NOx).

# Fields
- **`id`** is the name/identifyer of the resource.\n
- **`CO2_int::T`** is the the CO2 intensity.\n

"""
struct ResourceEmit{T<:Real} <: Resource
    id
    CO2_int::T
end

"""
General resources.
"""
struct ResourceCarrier{T<:Real} <: Resource
    id
    CO2_int::T
end

"""
    res_sub(𝒫::Array{Resource}, sub = ResourceEmit)

Return resources that are of type `sub` for a given Array `::Array{Resource}`.
"""
function res_sub(𝒫, sub = ResourceEmit)
    return 𝒫[findall(x -> isa(x, sub), 𝒫)]
end

"""
    res_not(𝒩::Array{Resource}, res_inst)

Return all resources that are not `res_inst` for a given Array `::Array{Resource}`.
"""
function res_not(𝒫, res_inst::Resource)
    return 𝒫[findall(x -> x!=res_inst, 𝒫)]
end

""" Declaration of the general type of node."""
abstract type Node end
Base.show(io::IO, n::Node) = print(io, "n_$(n.id)")

""" `Source` node with only output."""
abstract type Source <: Node end
""" `Network` node with both input and output."""
abstract type Network <: Node end
""" `Sink` node with only input."""
abstract type Sink <: Node end
""" `Storage` node with level."""
abstract type Storage <: Network end
""" `Availability` node as routing node."""
abstract type Availability <: Network end

""" Abstract type used to define concrete struct containing the package specific elements 
to add to the composite type defined in this package."""
abstract type Data end
""" Empty composite type for `Data`"""
struct EmptyData <: Data end

""" A reference `Source` node.

Process emissions can be included, but if the field is not added, then no
process emissions are assumed through the usage of a constructor.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`Cap::TimeProfile`** is the installed capacity.\n
- **`Opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`Opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`Output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`..\n
- **`Data::Array{Data}`** is the additional data (e.g. for investments).\n
- **`Emissions::Dict{ResourceEmit, Real}`**: emissions per energy unit produced.

"""
struct RefSource <: Source
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
RefSource(id, Cap, Opex_var, Opex_fixed, Output, Data) =
    RefSource(id, Cap, Opex_var, Opex_fixed, Output, Data, nothing)

""" A reference `Network` node.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`Cap::TimeProfile`** is the installed capacity.\n
- **`Opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`Opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`Input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.\n
- **`Output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`.\n
- **`Data::Array{Data}`** is the additional data (e.g. for investments).

"""
struct RefNetwork <: Network
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    Data::Array{Data}
end

""" A reference `Network` node with process emissions.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`Cap::TimeProfile`** is the installed capacity.\n
- **`Opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`Opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`Input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.\n
- **`Output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`.
CO2 is required to be included the be available to have CO2 capture applied properly.\n
- **`Emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`CO2_capture::Real`** is the CO2 capture rate.\n
- **`Data::Array{Data}`** is the additional data (e.g. for investments).

"""
struct RefNetworkEmissions <: Network
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    Emissions::Dict{ResourceEmit, Real}
    CO2_capture::Real
    Data::Array{Data}
end

""" A reference `Availability` node.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`Input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.
The latter are not relevant but included for consistency with other formulations.\n
- **`Output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`.
The latter are not relevant but included for consistency with other formulations.\n

"""
struct GenAvailability <: Availability
    id
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
end

""" A reference `Storage` node.

This node is designed to store a `ResourceCarrier`.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`Rate_cap::TimeProfile`** is the installed rate capacity, that is e.g. power or mass flow.\n
- **`Stor_cap::TimeProfile`** is the installed storage capacity, that is e.g. energy or mass.\n
- **`Opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`Opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`Stor_res::Resource`** is the stored `Resource`.\n
- **`Input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.
- **`Output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`.
Only relevant for linking and the stored `Resource`.\n
- **`Data::Array{Data}`** is the additional data (e.g. for investments).

"""
struct RefStorage <: Storage
    id
    Rate_cap::TimeProfile
    Stor_cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Stor_res::ResourceCarrier
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    Data::Array{Data}
end

""" A reference `Storage` node.

This node is designed to store a `ResourceEmit`.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`Rate_cap::TimeProfile`** is the installed rate capacity, that is e.g. power or mass flow.\n
- **`Stor_cap::TimeProfile`** is the installed storage capacity, that is e.g. energy or mass.\n
- **`Opex_var::TimeProfile`** is the variational operational costs per energy unit produced.\n
- **`Opex_fixed::TimeProfile`** is the fixed operational costs.\n
- **`Stor_res::Resource`** is the stored `Resource`.\n
- **`Input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.
- **`Output::Dict{Resource, Real}`** are the generated `Resource`s with conversion value `Real`.
Only relevant for linking and the stored `Resource`.\n
- **`Data::Array{Data}`** is the additional data (e.g. for investments).

"""
struct RefStorageEmissions <: Storage
    id
    Rate_cap::TimeProfile
    Stor_cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Stor_res::ResourceEmit
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    Data::Array{Data}
end

""" A reference `Sink` node.

This node corresponds to a demand given by the field `Cap`.
Process emissions can be included, but if the field is not added, then no
process emissions are assumed through the usage of a constructor.

# Fields
- **`id`** is the name/identifier of the node.\n
- **`Cap::TimeProfile`** is the Demand.\n
- **`Penalty::Dict{Any, TimeProfile}`** are penalties for surplus or deficits.
Requires the fields `:Surplus` and `:Deficit`.\n
- **`Input::Dict{Resource, Real}`** are the input `Resource`s with conversion value `Real`.\n
- **`Emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n

"""
struct RefSink <: Sink
    id
    Cap::TimeProfile
    Penalty::Dict{Any, TimeProfile}
    Input::Dict{Resource, Real}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
RefSink(id, Cap, Penalty, Input) =
    RefSink(id, Cap, Penalty, Input, nothing)

"""
    node_sub(𝒩::Array{Node}, sub/subs)

Return nodes that are of type sub/subs for a given Array `::Array{Node}`.
"""
function node_sub(𝒩::Array{Node}, sub = Network)
    return 𝒩[findall(x -> isa(x, sub), 𝒩)]
end

# function node_sub(𝒩::Array{Node}, subs...)
#     return 𝒩[findall(x -> sum(isa(x, sub) for sub in subs) >= 1, 𝒩)]
# end

"""
    node_not_sub(𝒩::Array{Node}, sub)

Return nodes that are not of type sub for a given Array `::Array{Node}`.
"""
function node_not_sub(𝒩::Array{Node}, sub = Network)
    return 𝒩[findall(x -> ~isa(x, sub), 𝒩)]
end

"""
    node_not_av(𝒩::Array{Node})

Return nodes that are not availability nodes for a given Array `::Array{Node}`.
"""
function node_not_av(𝒩::Array{Node})
    return 𝒩[findall(x -> ~isa(x, Availability), 𝒩)]
end

"""
    node_not_sink(𝒩::Array{Node})

Return nodes that are not Sink nodes for a given Array `::Array{Node}`.
"""
function node_not_sink(𝒩::Array{Node})
    return 𝒩[findall(x -> ~isa(x, Sink), 𝒩)]
end

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
- **`Formulation::Formulation`** is the used formulation of links. If not specified,
a `Linear` link is assumed\n

"""
struct Direct <: Link
    id
    from::Node
    to::Node
    Formulation::Formulation
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
function link_res(l::Link)
    return intersect(keys(l.to.Input), keys(l.from.Output))
end

""" Abstract type for differentation between types of models (investment, operational, ...)."""
abstract type EnergyModel end

"""
Operational Energy Model without investments.

# Fields
- **`Emission_limit`** is a dictionary with individual emission limits as `TimeProfile` for each 
emission resource `ResourceEmit`.\n
- **`CO2_instance`** is a `ResourceEmit` and corresponds to the type used for CO2.\n
"""
struct OperationalModel <: EnergyModel
    Emission_limit::Dict{ResourceEmit, TimeProfile}
    CO2_instance::ResourceEmit
end
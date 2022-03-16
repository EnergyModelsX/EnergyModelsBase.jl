# Declaration of the resources
abstract type Resource end
Base.show(io::IO, r::Resource) = print(io, "$(r.id)")
struct ResourceEmit{T<:Real}    <: Resource  # Emissions resources                   (e.g. CO2, CH4, NOX)
    id
    CO2Int::T
end
struct ResourceCarrier{T<:Real} <: Resource  # Ressources that can be transported    (e.g. power, NG, H2)
    id
    CO2Int::T
end

"""
    res_sub(𝒩::Array{Node}, sub)
Return resources that are of type sub for a given Array `::Array{Node}`.
"""
function res_sub(𝒫, sub = ResourceEmit)
    return 𝒫[findall(x -> isa(x,sub), 𝒫)]
end

# Declaration of the general type of node. This type has to be
# utilised for all technologies so that we can utilize multiple
# dispatch
abstract type Node end
Base.show(io::IO, n::Node) = print(io, "n$(n.id)")

"""
    node_sub(𝒩::Array{Node}, sub/subs)
Return nodes that are of type sub/subs for a given Array `::Array{Node}`.
"""
function node_sub(𝒩::Array{Node}, sub = Network)
    return 𝒩[findall(x -> isa(x,sub), 𝒩)]
end

# function node_sub(𝒩::Array{Node}, subs...)
#     return 𝒩[findall(x -> sum(isa(x, sub) for sub in subs) >= 1, 𝒩)]
# end

"""
    node_not_sub(𝒩::Array{Node}, sub)
Return nodes that are not of type sub for a given Array `::Array{Node}`.
"""
function node_not_sub(𝒩::Array{Node}, sub = Network)
    return 𝒩[findall(x -> ~isa(x,sub), 𝒩)]
end

"""
    node_not_av(𝒩::Array{Node})
Return nodes that are not availability nodes for a given Array `::Array{Node}`.
"""
function node_not_av(𝒩::Array{Node})
    return 𝒩[findall(x -> ~isa(x,Availability), 𝒩)]
end

"""
    node_not_sink(𝒩::Array{Node})
Return nodes that are not Sink nodes for a given Array `::Array{Node}`.
"""
function node_not_sink(𝒩::Array{Node})
    return 𝒩[findall(x -> ~isa(x,Sink), 𝒩)]
end

# Declaration of the individual technology node types representing
# a structure where we differentiate between whether nodes have 
# inputs, outputs, or both
abstract type Source <: Node end
abstract type Network <: Node end
abstract type Sink <: Node end
abstract type Storage <: Network end
abstract type Availability <: Network end

# abstarct type used to define concrete struct containing the package specific elements 
# to add to the concrete struct defined in this package.
abstract type Data end
struct EmptyData <: Data end

# Declaration of the parameters for generalized nodes
# Conversion as dict for prototyping: flexible, but inefficient
struct RefSource <: Source
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Output::Dict{Resource, Real}
    Emissions::Dict{ResourceEmit, Real}
    Data::Dict{String,Data}#Should it be a string?
end
struct RefGeneration <: Network
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    Emissions::Dict{ResourceEmit, Real}
    CO2_capture::Real
    Data::Dict{String,Data}
end
struct GenAvailability <: Availability
    id
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
end
struct RefStorage <: Storage
    id
    Rate_cap::TimeProfile
    Stor_cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    Data::Dict{String,Data}
end
struct RefSink <: Sink
    id
    Cap::TimeProfile
    Penalty::Dict{Any, Real}            # Requires entries deficit and surplus
    Input::Dict{Resource, Real}
    Emissions::Dict{ResourceEmit, Real}
end

abstract type Formulation end
struct Linear <: Formulation end
#struct NonLinear <: Formulation end # Example of extension

abstract type Link end
Base.show(io::IO, l::Link) = print(io, "l$(l.from)-$(l.to)")
struct Direct <: Link
    id
    from::Node
    to::Node
    Formulation::Formulation
end
#struct Transmission <: Link end # Example of extension


"""
    link_sub(ℒ, n::Node)
Return links for a given node  `::Array{Link}`.
"""
function link_sub(ℒ, n::Node)
    return [ℒ[findall(x -> x.from == n, ℒ)],
            ℒ[findall(x -> x.to   == n, ℒ)]]
end

"""
    link_res(l::Link)
Return resources for a given link l.
"""
function link_res(l::Link)
    return intersect(keys(l.to.Input), keys(l.from.Output))
end

abstract type AbstractGlobalData end
struct GlobalData <: AbstractGlobalData
    Emission_limit::Dict{ResourceEmit, TimeProfile}
end

abstract type EnergyModel end
struct OperationalModel <: EnergyModel
end
#struct InvestmentModel <: EnergyModel end # Example of extension
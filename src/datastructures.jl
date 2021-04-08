# Declaration of the resources
abstract type Ressource end
Base.show(io::IO, r::Ressource) = print(io, "$(r.id)")
struct RessourceEmit    <: Ressource  # Emissions resources not transported  (e.g. CO2, CH4, NOX)
    id
    CO2Int::Real
end
struct RessourceCarrier <: Ressource  # Ressources that can be transported    (e.g. power, NG, H2)
    id
    CO2Int::Real
end

# Function returning the emission resources
function res_sub(𝒫, sub = RessourceEmit)
    return 𝒫[findall(x -> isa(x,sub), 𝒫)]
end

# Declaration of the general type of node. This type has to be
# utilised for all technologies so that we can utilize multiple
# dispatch
abstract type Node end
Base.show(io::IO, n::Node) = print(io, "n$(n.id)")

# Function returning nodes with type corresponding the input "sub"
function node_sub(𝒩, sub = Network)
    return 𝒩[findall(x -> isa(x,sub), 𝒩)]
end

# Function exluding availability nodes
function node_not_av(𝒩)
    return 𝒩[findall(x -> ~isa(x,Availability), 𝒩)]
end

# Declaration of the individual technology node types representing
# a structure where we differentiate between whether nodes have 
# inputs, outputs, or both
abstract type Source <: Node end
abstract type Network <: Node end
abstract type Sink <: Node end
abstract type Storage <: Network end

# Declaration of the parameters for generalized nodes
# Conversion as dict for prototyping: flexible, but inefficient
struct RefSource <: Source
	id
    capacity::TimeProfile
    cost::TimeProfile
    conversion::Dict{Ressource, Real}
end
struct RefGeneration <: Network
	id
    capacity::TimeProfile
    cost::TimeProfile
    conversion::Dict{Ressource, Real}
    CO2_capture::Real
end
struct Availability <: Network
	id
end
struct RefStorage <: Storage
	id
    capacity::TimeProfile
    cost::TimeProfile
    ressource::Ressource
    add_demand::Dict{Ressource, Real}
end
struct RefEndUse <: Sink
	id
    capacity::TimeProfile
    penalty::Dict{Any, Real}            # Requires entries deficit and surplus
    conversion::Dict{Ressource, Real}
end

abstract type Formulation end
struct Linear <: Formulation end
#struct NonLinear <: Formulation end # Example of extension

abstract type Link end
Base.show(io::IO, l::Link) = print(io, "l$(l.from)-$(l.to)")
struct Direct <: Link
    from::Node
    to::Node
    Formulation::Formulation
end
#struct Transmission <: Link end # Example of extension


# Function returning linkes which are for a given node  ::Array{Link}
function link_sub(ℒ, n::Node)
    return [ℒ[findall(x -> x.from == n, ℒ)],
            ℒ[findall(x -> x.to   == n, ℒ)]]
end

abstract type EnergyModel end
struct OperationalModel <: EnergyModel end
#struct InvestmentModel <: EnergyModel end # Example of extension


abstract type Case end
struct OperationalCase <: Case
    nodes
    links
    time_structure
    products
end
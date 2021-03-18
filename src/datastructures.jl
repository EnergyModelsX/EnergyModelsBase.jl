abstract type Node end
Base.show(io::IO, n::Node) = print(io, "n$(n.id)")

abstract type Storage <: Node end

struct Battery <: Storage
	id
    capacity::TimeProfile
    properties::Dict{Any, Any} # for prototyping, flexible, but inefficient
end

struct GasTank <: Storage
	id
    capacity::TimeProfile
	properties::Dict{Any, Any}
end

abstract type Formulation end
struct Linear <: Formulation end
#struct NonLinear <: Formulation end # Example of extension

abstract type Link end
struct Direct <: Link end
#struct Transmission <: Link end # Example of extension

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

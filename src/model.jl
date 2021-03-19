
function create_model(data, modeltype=OperationalModel())
    @debug "Construct model"
    m = JuMP.Model()

    # WIP Data structure
    T = data[:T]          
    nodes = data[:nodes]  
    links = data[:links]
    products = data[:products]

    create_operational_variables(m, nodes, products, T, modeltype)
    create_network_variables(m, links, products, T, modeltype)
    create_capacity_variables(m, nodes, T, modeltype)
    create_constraints(m, nodes, T, modeltype)
    create_objective(m, nodes, T, modeltype)
    return m
end

function create_network_variables(m, ℒ, 𝒫, 𝒯, modeltype)

     @variable(m, flow[ℒ, 𝒯] >= 0)
end

function create_operational_variables(m, 𝒩, 𝒫, 𝒯, modeltype)
    
    @variable(m, flow_in[𝒩, 𝒫, 𝒯] >= 0) 
end

"""
    create_capacity_variables(m, 𝒩, 𝒯, modeltype=OperationalModel())

Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.
"""
function create_capacity_variables(m, 𝒩, 𝒯, modeltype=OperationalModel())
    
    @variable(m, cap_usage[𝒩, 𝒯] >= 0)
    
    # TODO:
    # If operational model, make variables bounded to fixed capacity(?)
    # If investment model, add variables and constraints to control available capacity
end

function create_capacity_constraints(m, 𝒩, 𝒯, modeltype)
    for n ∈ 𝒩, t ∈ 𝒯
        @constraint(m, cap_usage[n, t] <= n.capacity[t])
    end
end

function create_constraints(m, 𝒩, 𝒯, modeltype)

end

function create_objective(m,  𝒩, 𝒯, modeltype)

end


function define(m, i::Node, 𝒯, formulation=Linear())
	"Fallback"
end

# function define(m, i::Node, T, formulation::NonLinear)
# 	"Non-linear"
# end

# function link(m, from::Node, to::Node, T, link::Transmission, formulation=Linear())
# 	"generic transmission"
# end

function link(m, from::Node, to::Node, T, link=Direct(), formulation=Linear())
	"generic link"
end
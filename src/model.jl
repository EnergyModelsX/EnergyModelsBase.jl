# Construction of the model based on the provided data
function create_model(data, modeltype=OperationalModel())
    @debug "Construct model"
    m = JuMP.Model()

    # WIP Data structure
    T = data[:T]          
    nodes = data[:nodes]  
    links = data[:links]
    products = data[:products]

    # Declaration of variables for the problem
    create_variables_flow(m, nodes, T, products, links, modeltype)
    create_variables_emission(m, nodes, T, products, modeltype)
    create_variables_opex(m, nodes, T, products, modeltype)
    create_variables_capex(m, nodes, T, products, modeltype)
    create_variables_capacity(m, nodes, T, modeltype)
    create_variables_surplus_deficit(m, nodes, T, products, modeltype)

    # Construction of create_constraints for the problem
    create_constraints_module(m, nodes, T, products, links, modeltype)
    create_constraints_emissions(m, nodes, T, products, modeltype)
    create_constraints_links(m, nodes, T, products, links, modeltype)

    # Construction of th objective function
    create_objective(m, nodes, T, modeltype)

    return m
end

" Declaration of the individual input and output flowrates for each
technological node. This approach is also taken from eTransport.

Note, that we also require link variables in order to couple multiple
nodes to a single node."
function create_variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)

    𝒩ᵒᵘᵗ = node_sub(𝒩, Union{Source, Network})
    𝒩ⁱⁿ  = node_sub(𝒩, Union{Network, Sink})

    @variable(m, flow_in[𝒩ⁱⁿ, 𝒯, 𝒫] >= 0)
    @variable(m, flow_out[𝒩ᵒᵘᵗ, 𝒯, 𝒫] >= 0)

    @variable(m, link_in[ℒ, 𝒯, 𝒫] >= 0)
    @variable(m, link_out[ℒ, 𝒯, 𝒫] >= 0)
end

" Declaration of emission variables per technical node and investment
period. This approach is taken from eTransport for a modular description
of the system"
function create_variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)    
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)

    @variable(m, emissions_node[𝒩ⁿᵒᵗ, 𝒯, 𝒫ᵉᵐ]) 
    @variable(m, emissions_total[𝒯, 𝒫ᵉᵐ]) 
end

" Declaration of the variables used for calculating the costs of the problem
Note that they are not restricted to values larger than 0 as negative 
variable opex may me interesting to look at (sell of byproducts that are
not modeled)

These variables are independent whether the problem is an operational or
investment model as they are depending on the investment periods for
easier later analysis. "
function create_variables_opex(m, 𝒩, 𝒯, 𝒫, modeltype)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)    
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, opex_var[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ])
    @variable(m, opex_fixed[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
end

function create_variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m,capex[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
end

" Declaration of both surplus and deficit variables to quantify when there is
too much or too little energy for satisfying the demand in EndUse.

This approach can be extended to all sinks, but then again, we have to be 
careful that the parameters are provided.
"
function create_variables_surplus_deficit(m, 𝒩, 𝒯, 𝒫, modeltype)

    𝒩ˢⁱⁿᵏ = node_sub(𝒩, Sink)

    @variable(m,surplus[𝒩ˢⁱⁿᵏ, 𝒯] >= 0)
    @variable(m,deficit[𝒩ˢⁱⁿᵏ, 𝒯] >= 0)
end

"
Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.

In general, it is prefered to have the capacity as a function of a variable given
with a value of 1 in the field n.capacity
"
function create_variables_capacity(m, 𝒩, 𝒯, modeltype)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)

    @variable(m, cap_usage[𝒩ⁿᵒᵗ, 𝒯] >= 0)
    @variable(m, cap_max[𝒩ⁿᵒᵗ, 𝒯] >= 0)

    for n ∈ 𝒩ⁿᵒᵗ, t ∈ 𝒯
        @constraint(m, cap_max[n, t] == n.capacity[t])
    end
    # TODO:
    # - If operational model, make variables bounded to fixed capacity(?)
    # - If investment model, add variables and constraints to control available capacity
end

function create_variables_storage(m, 𝒩, 𝒯, modeltype)
    
    𝒩ˢᵗᵒʳ = node_sub(𝒩, Storage)

    @variable(m, bypass[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    # TODO:
    # - Bypass variables not necessary if we decide to work with availability module
    # - They can be incorporated if we decide to not use the availability module
end

" Declaration of the generalized module for constraint generation.
The concept is that we only utilize this constraint when model building and the individual
node type determines which constraints we need to load in the system.

The generalized module may incorporate different model concstraints that are common for all
types like the sum over all input flows. "

function create_constraints_module(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)

    # Constraints for summing up all input flows to avoid issues with respect to multiple
    # inlets and calling the corresponding module function
    for n ∈ 𝒩
        ℒᶠʳᵒᵐ, ℒᵗᵒ = link_sub(ℒ, n)
        if isa(n,Union{Source, Network})
            @constraint(m, [t ∈ 𝒯, p ∈ 𝒫], 
                m[:flow_out][n, t, p] == sum(m[:link_in][l,t,p] for l in ℒᶠʳᵒᵐ))
        end
        if isa(n,Union{Network, Sink})
            @constraint(m, [t ∈ 𝒯, p ∈ 𝒫], 
                m[:flow_in][n, t, p] == sum(m[:link_out][l,t,p] for l in ℒᵗᵒ))
        end
        create_module(m, n, 𝒯, 𝒫)
    end

    # Constraints for fixed OPEX and capital cost constraints
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ], m[:opex_fixed][n, t_inv] == 0)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ], m[:capex][n, t_inv] == 0)
end

function create_constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype)
    
    # Constraints for calculation the total emissions per investment period and
    # limiting said emissions to a maximum value, currentkly hard coded
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_total][t, p] == sum(m[:emissions_node][n, t, p] for n ∈ 𝒩ⁿᵒᵗ))
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ],
        sum(m[:emissions_total][t, p] for t ∈ t_inv) <= 450)
end

function create_objective(m, 𝒩, 𝒯, modeltype)

    # Calculation of the objective function
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @objective(m, Min, sum(m[:opex_var][n, t] + m[:opex_fixed][n, t] + m[:capex][n, t] for t ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ))
end

function create_constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)
    # Constraints for links between two nodes
    # These constraints are generalized and create the constraints between all coupled
    # nodes
    for l ∈ ℒ 
        link(m, l.from,l.to, 𝒯, 𝒫, l, l.Formulation)
    end

end

" Declaration of the individual standard modules for the different types used in
the system.
"

function create_module(m, n::Source, 𝒯, 𝒫)

    # Constraint for the individual stream connections
    for p ∈ 𝒫
        if n.conversion[p] >= 0
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p] == m[:cap_usage][n, t]*n.conversion[p])
        end
    end
    # Constraint for the maximum capacity
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] <= m[:cap_max][n, t])
    
    # Constraint for the emissions associated to energy sources, currently set to 0
    𝒫ᵉᵐ = res_sub(𝒫, ResourceEmit)
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p] == 0)

    # Constraint for the Opex contributions
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_usage][n, t]*n.cost[t] for t ∈ t_inv))
end

function create_module(m, n::Network, 𝒯, 𝒫)

    𝒫ᵉᵐ = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual stream connections
    for p ∈ 𝒫
        if n.conversion[p] > 0
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_in][n, t, p]  == 0)
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p] == m[:cap_usage][n, t]*n.conversion[p])
        else
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_in][n, t, p] == -m[:cap_usage][n, t]*n.conversion[p])
            if p ∈ 𝒫ᵉᵐ
                @constraint(m, [t ∈ 𝒯], 
                    m[:flow_out][n, t, p]  == n.CO2_capture*sum(p2.CO2Int*m[:flow_in][n, t, p2] for p2 ∈ 𝒫))
            else
                @constraint(m, [t ∈ 𝒯], 
                    m[:flow_out][n, t, p]  == 0)
            end
        end
    end
    # Constraint for the maximum capacity
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] <= m[:cap_max][n, t])
    
    # Constraint for the emissions associated to energy sources based on CO2 capture rate
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == 
            (1-n.CO2_capture)*sum(p.CO2Int*m[:flow_in][n, t, p] for p ∈ 𝒫))

    # Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_usage][n, t]*n.cost[t] for t ∈ t_inv))
end

function create_module(m, n::Storage, 𝒯, 𝒫)

    # Declaration of the required subsets
    𝒫ˢᵗᵒʳ = n.resource
    𝒫ᵃᵈᵈ  = 𝒫[findall(x -> x != n.resource, 𝒫)]
    𝒫ᵉᵐ   = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

    # Constraint for additional required input
    for p ∈ 𝒫ᵃᵈᵈ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_in][n, t, p] == -m[:flow_in][n, t, 𝒫ˢᵗᵒʳ]*n.add_demand[p])
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_out][n, t, p] == 0)
    end

    # Mass balance constraints
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] <= m[:cap_max][n, t])
    for t_inv ∈ 𝒯ᴵⁿᵛ 
        for t ∈ t_inv
            if t == first_operational(t_inv)
                if 𝒫ˢᵗᵒʳ ∈ 𝒫ᵉᵐ
                    @constraint(m,
                        m[:cap_usage][n, t] ==  m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                                m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ]
                        )
                    @constraint(m, m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ] >= 0)
                else
                    @constraint(m,
                        m[:cap_usage][n, t] ==  m[:cap_usage][n, last_operational(t_inv)] + 
                                                m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                                m[:flow_out][n, t , 𝒫ˢᵗᵒʳ]
                        )
                end
            else
                if 𝒫ˢᵗᵒʳ ∈ 𝒫ᵉᵐ
                    @constraint(m,
                        m[:cap_usage][n, t] ==  m[:cap_usage][n, previous(t)] + 
                                                m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                                m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ]
                        )
                    @constraint(m, m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ] >= 0)
                else
                    @constraint(m,
                        m[:cap_usage][n, t] ==  m[:cap_usage][n, previous(t)] + 
                                                m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                                m[:flow_out][n, t , 𝒫ˢᵗᵒʳ]
                        )
                end
            end
        end
    end
    
    # Constraint for the emissions
    for p_em ∈ 𝒫ᵉᵐ
        if p_em != 𝒫ˢᵗᵒʳ
            @constraint(m, [t ∈ 𝒯],
                m[:emissions_node][n, t, p_em] == 
                    0)
        end
    end

    # Constraint for the Opex contributions
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum((m[:flow_in][n, t , 𝒫ˢᵗᵒʳ]-m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ])*n.cost[t] for t ∈ t_inv))
end

function create_module(m, n::Sink, 𝒯, 𝒫)
    
    # Constraint for the individual stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫],
        m[:flow_in][n, t, p] == -m[:cap_usage][n, t]*n.conversion[p])

    # Constraint for the mass balance allowing surplus and deficit
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] + m[:deficit][n,t] == 
            m[:cap_max][n, t] + m[:surplus][n,t])

    # Constraint for the emissions
    𝒫ᵉᵐ = res_sub(𝒫, ResourceEmit)
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p] == 0)

    # Constraint for the Opex contributions
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum(m[:surplus][n, t]*n.penalty[:surplus] + m[:deficit][n, t]*n.penalty[:deficit] for t ∈ t_inv))
end

function create_module(m, n::Availability, 𝒯, 𝒫)

    # Mass balance constraints for an availability node
    # Note that it is not necessary to have availability nodes for
    # each individual energy carrier as the links contain the knowledge
    # of the different energy carriers
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫],
        m[:flow_in][n, t, p] == m[:flow_out][n, t, p])
end


function create_module(m, n, 𝒯, 𝒫)
    nothing
end

"Declaration of the individual links used in the model.
"

function link(m, from::Node, to::Node, 𝒯, 𝒫, l, formulation)
	# Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫],
        m[:link_out][l, t, p] == m[:link_in][l, t, p])
end

# function link(m, from::Node, to::Node, 𝒯, 𝒫, link::Transmission, formulation=Linear())
# 	"generic transmission"
# end

"Open topics:
- Emissions associated to usage of the individual energy carriers has to be carefully assessed.
  Currently, this is implemented as fixed emission coefficient for CO2 emissions only based on
  the input. Within storage, this may however not be true.
  As an alternative, we could utilize also a different approach with an updated dictionary in
  which the variables are later changed (mutable structure)
- Shall we keep the not availability case for exluding certain nodes for certain variables?
  This is mostly related to avoiding emission and cost parameters for the availability nodes
- It may be necessary to obtain also the first and last value in a strategic period. This has
  to be adjusted in TimeStructures package
"

"Hard coded values:
- Maximum emissions
- Emissions for Source and Sink
- Fixed OPEX for all modules
"
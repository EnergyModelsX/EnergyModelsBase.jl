# Construction of the model based on the provided data
function create_model(data, modeltype)
    @debug "Construct model"
    m = JuMP.Model()

    # WIP Data structure
    T = data[:T]          
    nodes = data[:nodes]  
    links = data[:links]
    products = data[:products]

    # Check if the data is consistent before the model is created.
    check_data(data, modeltype)

    # Declaration of variables for the problem
    variables_flow(m, nodes, T, products, links, modeltype)
    variables_emission(m, nodes, T, products, modeltype)
    variables_opex(m, nodes, T, products, modeltype)
    variables_capex(m, nodes, T, products, modeltype)
    variables_capacity(m, nodes, T, modeltype)
    variables_surplus_deficit(m, nodes, T, products, modeltype)
    variables_storage(m, nodes, T, modeltype)
    variables_node(m, nodes, T, modeltype)

    # Construction of constraints for the problem
    constraints_node(m, nodes, T, products, links, modeltype)
    constraints_emissions(m, nodes, T, products, modeltype)
    constraints_links(m, nodes, T, products, links, modeltype)

    # Construction of the objective function
    objective(m, nodes, T, products, modeltype)

    return m
end

"
Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.

In general, it is prefered to have the capacity as a function of a variable given
with a value of 1 in the field n.capacity
"
function variables_capacity(m, 𝒩, 𝒯, modeltype)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)

    @variable(m, cap_usage[𝒩ⁿᵒᵗ, 𝒯] >= 0)
    @variable(m, inst_cap[𝒩ⁿᵒᵗ, 𝒯] >= 0)

    for n ∈ 𝒩ⁿᵒᵗ, t ∈ 𝒯
        @constraint(m, inst_cap[n, t] == n.capacity[t])
    end
    # TODO:
    # - If operational model, make variables bounded to fixed capacity(?)
    # - If investment model, add variables and constraints to control available capacity
end

" Declaration of the individual input and output flowrates for each
technological node. This approach is also taken from eTransport.

Note, that we also require link variables in order to couple multiple
nodes to a single node."
function variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)

    𝒩ᵒᵘᵗ = node_sub(𝒩, Union{Source, Network})
    𝒩ⁱⁿ  = node_sub(𝒩, Union{Network, Sink})

    @variable(m, flow_in[n_in ∈ 𝒩ⁱⁿ,    𝒯, keys(n_in.input)] >= 0)
    @variable(m, flow_out[n_out ∈ 𝒩ᵒᵘᵗ, 𝒯, keys(n_out.output)] >= 0)

    @variable(m, link_in[l ∈ ℒ,  𝒯, link_res(l)] >= 0)
    @variable(m, link_out[l ∈ ℒ, 𝒯, link_res(l)] >= 0)
end

" Declaration of emission variables per technical node and investment
period. This approach is taken from eTransport for a modular description
of the system"
function variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)    
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, emissions_node[𝒩ⁿᵒᵗ, 𝒯, 𝒫ᵉᵐ] >= 0) 
    @variable(m, emissions_total[𝒯, 𝒫ᵉᵐ] >= 0) 
    @variable(m, emissions_strategic[t_inv ∈ 𝒯ᴵⁿᵛ, 𝒫ᵉᵐ] <= modeltype.case.CO2_limit[t_inv]) 
end

" Declaration of the variables used for calculating the costs of the problem
Note that they are not restricted to values larger than 0 as negative 
variable opex may me interesting to look at (sell of byproducts that are
not modeled)

These variables are independent whether the problem is an operational or
investment model as they are depending on the investment periods for
easier later analysis. "
function variables_opex(m, 𝒩, 𝒯, 𝒫, modeltype)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)    
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, opex_var[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ])
    @variable(m, opex_fixed[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
end

function variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒩ˢᵗᵒʳ = node_sub(𝒩, Storage)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m,capex[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m,capex_stor[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)

end

" Declaration of both surplus and deficit variables to quantify when there is
too much or too little energy for satisfying the demand in EndUse.

This approach can be extended to all sinks, but then again, we have to be 
careful that the parameters are provided.
"
function variables_surplus_deficit(m, 𝒩, 𝒯, 𝒫, modeltype)

    𝒩ˢⁱⁿᵏ = node_sub(𝒩, Sink)

    @variable(m,surplus[𝒩ˢⁱⁿᵏ, 𝒯] >= 0)
    @variable(m,deficit[𝒩ˢⁱⁿᵏ, 𝒯] >= 0)
end

function variables_storage(m, 𝒩, 𝒯, modeltype)
    𝒩ˢᵗᵒʳ = node_sub(𝒩, Storage)

    # @variable(m, bypass[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_level[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, inst_stor[𝒩ˢᵗᵒʳ, 𝒯] >= 0)

    @constraint(m, [n ∈ 𝒩ˢᵗᵒʳ, t ∈ 𝒯], m[:inst_stor][n, t] == n.cap_stor[t])
    
    # TODO:
    # - Bypass variables not necessary if we decide to work with availability create_node
    # - They can be incorporated if we decide to not use the availability create_node
end


" Call a method for creating e.g. other variables specific to the different 
node types. The method is only called once for each node type. "
function variables_node(m, 𝒩, 𝒯, modeltype)
    nodetypes = []
    for node in 𝒩
        if ! (typeof(node) in nodetypes)
            variables_node(m, 𝒩, 𝒯, node, modeltype)
            push!(nodetypes, typeof(node))
        end
    end
end

" Default fallback method. "
variables_node(m, 𝒩, 𝒯, node, modeltype) = nothing


" Declaration of the generalized create_node for constraint generation.
The concept is that we only utilize this constraint when model building and the individual
node type determines which constraints we need to load in the system.

The generalized node may incorporate different model concstraints that are common for all
types like the sum over all input flows. "

function constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)

    # Constraints for summing up all input flows to avoid issues with respect to multiple
    # inlets and calling the corresponding node function
    for n ∈ 𝒩
        ℒᶠʳᵒᵐ, ℒᵗᵒ = link_sub(ℒ, n)
        if isa(n,Union{Source, Network})
            @constraint(m, [t ∈ 𝒯, p ∈ keys(n.output)], 
                m[:flow_out][n, t, p] == sum(m[:link_in][l,t,p] for l in ℒᶠʳᵒᵐ if p ∈ keys(l.to.input)))
        end
        if isa(n,Union{Network, Sink})
            @constraint(m, [t ∈ 𝒯, p ∈ keys(n.input)], 
                m[:flow_in][n, t, p] == sum(m[:link_out][l,t,p] for l in ℒᵗᵒ if p ∈ keys(l.from.output)))
        end
        create_node(m, n, 𝒯, 𝒫)
    end

    # Constraints for fixed OPEX and capital cost constraints
    𝒩ⁿᵒᵗ = node_not_sink(node_not_av(𝒩))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ], m[:opex_fixed][n, t_inv] == n.fixed_opex[t_inv] * t_inv.duration)
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ], m[:capex][n, t_inv] == 0)
end

function constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype)
    
    # Constraints for calculation the total emissions per investment period and
    # limiting said emissions to a maximum value, currentkly hard coded
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_total][t, p] == sum(m[:emissions_node][n, t, p] for n ∈ 𝒩ⁿᵒᵗ))
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ],
        m[:emissions_strategic][t_inv, p] == sum(m[:emissions_total][t, p] for t ∈ t_inv))
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ],
    #     m[:emissions_strategic][t_inv, p] <= modeltype.case.CO2_limit[t_inv])
end

function objective(m, 𝒩, 𝒯, 𝒫, modeltype)

    # Calculation of the objective function
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @objective(m, Min, sum(m[:opex_var][n, t] + m[:opex_fixed][n, t] + m[:capex][n, t] for t ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ))
end

function constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)
    # Constraints for links between two nodes
    # These constraints are generalized and create the constraints between all coupled
    # nodes
    for l ∈ ℒ 
        create_link(m, 𝒯, 𝒫, l, l.Formulation)
    end

end

" Declaration of the individual standard modules for the different types used in
the system.
"

function create_node(m, n::Source, 𝒯, 𝒫)

    # Declaration of the required subsets
    𝒫ᵒᵘᵗ = keys(n.output)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual stream connections
    for p ∈ 𝒫ᵒᵘᵗ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_out][n, t, p] == m[:cap_usage][n, t]*n.output[p])
    end
    # Constraint for the maximum capacity
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] <= m[:inst_cap][n, t])
    
    # Constraint for the emissions associated to energy sources, currently set to 0
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_usage][n, t]*n.emissions[p_em])

    # Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_usage][n, t] * n.var_opex[t] * t.duration for t ∈ t_inv))
end


function create_node(m, n::Network, 𝒯, 𝒫)

    # Declaration of the required subsets
    𝒫ⁱⁿ  = keys(n.input)
    𝒫ᵒᵘᵗ = keys(n.output)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual stream connections
    for p ∈ 𝒫ⁱⁿ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_in][n, t, p] == m[:cap_usage][n, t]*n.input[p])
    end
    for p ∈ 𝒫ᵒᵘᵗ
        if p.id == "CO2"
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p]  == n.CO2_capture*sum(p_in.CO2Int*m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ))
        else
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p] == m[:cap_usage][n, t]*n.output[p])
        end
    end

    # Constraint for the maximum capacity
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] <= m[:inst_cap][n, t])
    
    # Constraint for the emissions associated to energy sources based on CO2 capture rate
    # I am quite certain, that this could be represented better in JuMP, but then again I
    # do not know JuMP at the moment sufficiently well to avoid logic statements here
    for p_em ∈ 𝒫ᵉᵐ
        if p_em.id == "CO2"
            @constraint(m, [t ∈ 𝒯],
                m[:emissions_node][n, t, p_em] == 
                    (1-n.CO2_capture)*sum(p_in.CO2Int*m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ) + 
                    m[:cap_usage][n, t]*n.emissions[p_em])
        else
            @constraint(m, [t ∈ 𝒯],
                m[:emissions_node][n, t, p_em] == 
                    m[:cap_usage][n, t]*n.emissions[p_em])
        end
    end
            
    # Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_usage][n, t] * n.var_opex[t] * t.duration for t ∈ t_inv))
end

function create_node(m, n::Storage, 𝒯, 𝒫)

    # Declaration of the required subsets
    𝒫ˢᵗᵒʳ = [k for (k,v) ∈ n.input if v == 1][1]
    𝒫ᵃᵈᵈ  = setdiff(keys(n.input), [𝒫ˢᵗᵒʳ])
    𝒫ᵉᵐ   = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

    # Constraint for additional required input
    for p ∈ 𝒫ᵃᵈᵈ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_in][n, t, p] == m[:flow_in][n, t, 𝒫ˢᵗᵒʳ]*n.input[p])
    end

    # Convention for cap_usage when it is used with a Storage.
    @constraint(m, [t ∈ 𝒯], m[:cap_usage][n, t] == m[:flow_in][n, t, 𝒫ˢᵗᵒʳ])

    @constraint(m, [t ∈ 𝒯], m[:cap_usage][n, t] <= m[:inst_cap][n, t])

    # Mass balance constraints
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] <= m[:inst_stor][n, t])
    for t_inv ∈ 𝒯ᴵⁿᵛ 
        for t ∈ t_inv
            if t == first_operational(t_inv)
                if 𝒫ˢᵗᵒʳ ∈ 𝒫ᵉᵐ
                    @constraint(m,
                        m[:stor_level][n, t] ==  m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                                m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ]
                        )
                    @constraint(m, m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ] >= 0)
                else
                    @constraint(m,
                        m[:stor_level][n, t] ==  m[:stor_level][n, last_operational(t_inv)] + 
                                                m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                                m[:flow_out][n, t , 𝒫ˢᵗᵒʳ]
                        )
                end
            else
                if 𝒫ˢᵗᵒʳ ∈ 𝒫ᵉᵐ
                    @constraint(m,
                        m[:stor_level][n, t] ==  m[:stor_level][n, previous(t)] + 
                                                m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                                m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ]
                        )
                    @constraint(m, m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ] >= 0)
                else
                    @constraint(m,
                        m[:stor_level][n, t] ==  m[:stor_level][n, previous(t)] + 
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
        m[:opex_var][n, t_inv] == sum((m[:flow_in][n, t , 𝒫ˢᵗᵒʳ]-m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ])*n.var_opex[t] for t ∈ t_inv))
end

function create_node(m, n::Sink, 𝒯, 𝒫)
    
    # Declaration of the required subsets
    𝒫ⁱⁿ  = keys(n.input)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:flow_in][n, t, p] == m[:cap_usage][n, t]*n.input[p])

    # Constraint for the mass balance allowing surplus and deficit
    @constraint(m, [t ∈ 𝒯],
        m[:cap_usage][n, t] + m[:deficit][n,t] == 
            m[:inst_cap][n, t] + m[:surplus][n,t])

    # Constraint for the emissions
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_usage][n, t]*n.emissions[p_em])

    # Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum((m[:surplus][n, t] * n.penalty[:surplus] 
                + m[:deficit][n, t] * n.penalty[:deficit])
                * t.duration for t ∈ t_inv))
end

function create_node(m, n::Availability, 𝒯, 𝒫)

    # Mass balance constraints for an availability node
    # Note that it is not necessary to have availability nodes for
    # each individual energy carrier as the links contain the knowledge
    # of the different energy carriers
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫],
        m[:flow_in][n, t, p] == m[:flow_out][n, t, p])
end

# function create_node(m, n, 𝒯, 𝒫)
#     nothing
# end

"Declaration of the individual links used in the model.
"

function create_link(m, 𝒯, 𝒫, l, formulation)
	# Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ link_res(l)],
        m[:link_out][l, t, p] == m[:link_in][l, t, p])
end

# function link(m, 𝒯, 𝒫, link::Transmission, formulation=Linear())
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
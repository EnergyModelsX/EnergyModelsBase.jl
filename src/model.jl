"""
    create_model(case, modeltype::EnergyModel)

Create the model and call all requried functions based on provided 'modeltype'
and case data.
"""
function create_model(case, modeltype::EnergyModel)
    @debug "Construct model"
    m = JuMP.Model()

    # WIP Data structure
    T           = case[:T]          
    nodes       = case[:nodes]  
    links       = case[:links]
    products    = case[:products]
    global_data = case[:global_data]

    # Check if the case data is consistent before the model is created.
    check_data(case, modeltype)

    # Declaration of variables for the problem
    variables_flow(m, nodes, T, products, links, modeltype)
    variables_emission(m, nodes, T, products, global_data, modeltype)
    variables_opex(m, nodes, T, products, global_data, modeltype)
    variables_capex(m, nodes, T, products, global_data, modeltype)
    variables_capacity(m, nodes, T, global_data, modeltype)
    variables_surplus_deficit(m, nodes, T, products, modeltype)
    variables_storage(m, nodes, T, global_data, modeltype)
    variables_node(m, nodes, T, modeltype)

    # Construction of constraints for the problem
    constraints_node(m, nodes, T, products, links, modeltype)
    constraints_emissions(m, nodes, T, products, global_data, modeltype)
    constraints_links(m, nodes, T, products, links, modeltype)

    # Construction of the objective function
    objective(m, nodes, T, products, global_data, modeltype)

    return m
end

"""
    variables_capacity(m, 𝒩, 𝒯, global_data::AbstractGlobalData, modeltype::EnergyModel)

Create variables `:cap_use` to track how much of installed capacity is used in each node
in terms of either `:flow_in` or `:flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`. The variables are **not** created for `Storage` or `Availability` nodes.
In general, it is prefered to have the capacity as a function of a variable given with a
value of 1 in the field `n.Cap`.

Create variables `:cap_inst` corresponding to installed capacity and constrains the variable
to the specified capacity `n.Cap`.
"""
function variables_capacity(m, 𝒩, 𝒯, global_data::AbstractGlobalData, modeltype::EnergyModel)
    
    𝒩ⁿᵒᵗ = node_not_sub(𝒩, Union{Storage, Availability})

    @variable(m, cap_use[𝒩ⁿᵒᵗ, 𝒯] >= 0)
    @variable(m, cap_inst[𝒩ⁿᵒᵗ, 𝒯] >= 0)

    for n ∈ 𝒩ⁿᵒᵗ, t ∈ 𝒯
        @constraint(m, cap_inst[n, t] == n.Cap[t])
    end
end

"""
    variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

Declaration of the individual input (`:flow_in`) and output (`:flow_out`) flowrates for
each technological node `n ∈ 𝒩` and link `l ∈ ℒ` (`:link_in` and `:link_out`).
"""
function variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

    𝒩ᵒᵘᵗ = node_sub(𝒩, Union{Source, Network})
    𝒩ⁱⁿ  = node_sub(𝒩, Union{Network, Sink})

    @variable(m, flow_in[n_in ∈ 𝒩ⁱⁿ,    𝒯, keys(n_in.Input)] >= 0)
    @variable(m, flow_out[n_out ∈ 𝒩ᵒᵘᵗ, 𝒯, keys(n_out.Output)] >= 0)

    @variable(m, link_in[l ∈ ℒ,  𝒯, link_res(l)] >= 0)
    @variable(m, link_out[l ∈ ℒ, 𝒯, link_res(l)] >= 0)
end

"""
    variables_emission(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)

Declaration of emission variables per technical node `n ∈ 𝒩` and emission resource `𝒫ᵉᵐ ∈ 𝒫`.
These are differentied in:
  * `:emissions_node` - emissions of a node in an operational period,
  * `:emissions_total` - total emissions in an operational period, and
  * `:emissions_strategic` - total strategic emissions, constrained to an upper limit based on 
  `global_data.Emission_limit`.
"""
function variables_emission(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)    
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, emissions_node[𝒩ⁿᵒᵗ, 𝒯, 𝒫ᵉᵐ] >= 0) 
    @variable(m, emissions_total[𝒯, 𝒫ᵉᵐ] >= 0) 
    @variable(m, emissions_strategic[t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ] <= global_data.Emission_limit[p][t_inv]) 
end

"""
    variables_opex(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)

Declaration of the OPEX variables (`:opex_var` and `:opex_fixed`) of the model for each investment
period `𝒯ᴵⁿᵛ ∈ 𝒯`. Variable OPEX can be non negative to account for revenue streams.
"""
function variables_opex(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)    
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, opex_var[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ])
    @variable(m, opex_fixed[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
end

"""
    variables_capex(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)

Declaration of the CAPEX variables of the model for each investment period `𝒯ᴵⁿᵛ ∈ 𝒯`. 
Empty for operational models but required for multiple dispatch in investment model.
"""
function variables_capex(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)
end

"""
    variables_surplus_deficit(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

Declaration of both surplus (`:sink_surplus`) and deficit (`:sink_deficit`) variables
for `Sink` nodes `𝒩ˢⁱⁿᵏ` to quantify when there is too much or too little energy for
satisfying the demand.
"""
function variables_surplus_deficit(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

    𝒩ˢⁱⁿᵏ = node_sub(𝒩, Sink)

    @variable(m,sink_surplus[𝒩ˢⁱⁿᵏ, 𝒯] >= 0)
    @variable(m,sink_deficit[𝒩ˢⁱⁿᵏ, 𝒯] >= 0)
end

"""
    variables_storage(m, 𝒩, 𝒯, 𝒫, modeltype)

Declaration of different storage variables for `Storage` nodes `𝒩ˢᵗᵒʳ`. These variables are:

  * `:stor_level` - storage level in each operational period
  * `:stor_rate_use` - change of level in each operational period
  * `:stor_cap_inst` - installed capacity for storage in each operational period, constrained
  in the operational case to `n.Stor_cap` 
  * `:stor_rate_inst` - installed rate for storage, e.g. power in each operational period,
  constrained in the operational case to `n.Rate_cap` 
"""
function variables_storage(m, 𝒩, 𝒯, global_data::AbstractGlobalData, modeltype::EnergyModel)

    𝒩ˢᵗᵒʳ = node_sub(𝒩, Storage)

    @variable(m, stor_level[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_rate_use[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_cap_inst[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_rate_inst[𝒩ˢᵗᵒʳ, 𝒯] >= 0)

    @constraint(m, [n ∈ 𝒩ˢᵗᵒʳ, t ∈ 𝒯], m[:stor_cap_inst][n, t] == n.Stor_cap[t])
    @constraint(m, [n ∈ 𝒩ˢᵗᵒʳ, t ∈ 𝒯], m[:stor_rate_inst][n, t] == n.Rate_cap[t])
end


"""
    variables_node(m, 𝒩, 𝒯, modeltype::EnergyModel)

Call a method for creating e.g. other variables specific to the different 
node types. The method is only called once for each node type.
"""
function variables_node(m, 𝒩, 𝒯, modeltype::EnergyModel)
    nodetypes = []
    for node in 𝒩
        if ! (typeof(node) in nodetypes)
            variables_node(m, 𝒩, 𝒯, node, modeltype)
            push!(nodetypes, typeof(node))
        end
    end
end

""""
    variables_node(m, 𝒩, 𝒯, node, modeltype::EnergyModel)

Default fallback method when no function is defined for a node type.
"""
function variables_node(m, 𝒩, 𝒯, node, modeltype::EnergyModel)
end


"""
    constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

Create link constraints for each `n ∈ 𝒩` depending on its type and calling the function
`create_node(m, n, 𝒯, 𝒫)` for the individual node constraints.

Create constraints for fixed OPEX.
"""
function constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

    for n ∈ 𝒩
        ℒᶠʳᵒᵐ, ℒᵗᵒ = link_sub(ℒ, n)
        # Constraint for output flowrate and input links.
        if isa(n, Union{Source, Network})
            @constraint(m, [t ∈ 𝒯, p ∈ keys(n.Output)], 
                m[:flow_out][n, t, p] == sum(m[:link_in][l, t, p] for l in ℒᶠʳᵒᵐ if p ∈ keys(l.to.Input)))
        end
        # Constraint for input flowrate and output links.
        if isa(n, Union{Network, Sink})
            @constraint(m, [t ∈ 𝒯, p ∈ keys(n.Input)], 
                m[:flow_in][n, t, p] == sum(m[:link_out][l, t, p] for l in ℒᵗᵒ if p ∈ keys(l.from.Output)))
        end
        # Call of function for individual node constraints.
        create_node(m, n, 𝒯, 𝒫)
    end

    # Declaration of the required subsets.
    𝒩ⁿᵒᵗ    = node_not_sub(𝒩,Union{Storage, Availability, Sink})
    𝒩ˢᵗᵒʳ   = node_sub(𝒩, Storage)
    𝒯ᴵⁿᵛ    = strategic_periods(𝒯)

    # Constraints for fixed OPEX constraints
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ], m[:opex_fixed][n, t_inv] == n.Opex_fixed[t_inv] * 
                                             m[:cap_inst][n, first(t_inv)])
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ˢᵗᵒʳ], m[:opex_fixed][n, t_inv] == n.Opex_fixed[t_inv] * 
                                              m[:stor_cap_inst][n, first(t_inv)])
end

"""
    constraints_emissions(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)

Create constraints for the emissions accounting for both operational and strategic periods.
"""
function constraints_emissions(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)
    
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Creation of the individual constraints.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_total][t, p] == sum(m[:emissions_node][n, t, p] for n ∈ 𝒩ⁿᵒᵗ))
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ],
        m[:emissions_strategic][t_inv, p] == sum(m[:emissions_total][t, p] * t.duration for t ∈ t_inv))
end

"""
    objective(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)

Create the objective for the optimization problem for a given modeltype. 
"""
function objective(m, 𝒩, 𝒯, 𝒫, global_data::AbstractGlobalData, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒩ⁿᵒᵗ = node_not_av(𝒩)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Calculation of the objective function.
    @objective(m, Max, -sum((m[:opex_var][n, t_inv] + m[:opex_fixed][n, t_inv]) * t_inv.duration for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ))
end

"""
    constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

Call the function `create_link` for link formulation
"""
function constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)
    for l ∈ ℒ 
        create_link(m, 𝒯, 𝒫, l, l.Formulation)
    end

end

"""
    create_node(m, n::Source, 𝒯, 𝒫)

Set all constraints for a `Source`. Can serve as fallback option for all unspecified
subtypes of `Source`.
"""
function create_node(m, n::Source, 𝒯, 𝒫)

    # Declaration of the required subsets.
    𝒫ᵒᵘᵗ = keys(n.Output)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual output stream connections.
    for p ∈ 𝒫ᵒᵘᵗ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_out][n, t, p] == m[:cap_use][n, t]*n.Output[p])
    end
    # Constraint for the maximum capacity.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t])
    
    # Constraint for the emissions associated to using the source.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * n.Emissions[p_em])

    # Constraint for the variable OPEX contribution.
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::Network, 𝒯, 𝒫)

Set all constraints for a `Network`. Can serve as fallback option for all unspecified
subtypes of `Network`.
"""
function create_node(m, n::Network, 𝒯, 𝒫)

    # Declaration of the required subsets.
    𝒫ⁱⁿ  = keys(n.Input)
    𝒫ᵒᵘᵗ = keys(n.Output)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual input stream connections.
    for p ∈ 𝒫ⁱⁿ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_in][n, t, p] == m[:cap_use][n, t] * n.Input[p])
    end
    # Constraint for the individual output stream connections. Captured CO2 is also included based on
    # the capture rate
    for p ∈ 𝒫ᵒᵘᵗ
        if p.id == "CO2"
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p]  == n.CO2_capture * sum(p_in.CO2Int * m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ))
        else
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p] == m[:cap_use][n, t] * n.Output[p])
        end
    end

    # Constraint for the maximum capacity.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t])
    
    # Constraint for the emissions associated to energy sources based on CO2 capture rate
    # I am quite certain, that this could be represented better in JuMP, but then again I
    # do not know JuMP at the moment sufficiently well to avoid logic statements here
    for p_em ∈ 𝒫ᵉᵐ
        if p_em.id == "CO2"
            @constraint(m, [t ∈ 𝒯],
                m[:emissions_node][n, t, p_em] == 
                    (1-n.CO2_capture) * sum(p_in.CO2Int * m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ) + 
                    m[:cap_use][n, t] * n.Emissions[p_em])
        else
            @constraint(m, [t ∈ 𝒯],
                m[:emissions_node][n, t, p_em] == 
                    m[:cap_use][n, t] * n.Emissions[p_em])
        end
    end
            
    # Constraint for the variable OPEX contribution.
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::Storage, 𝒯, 𝒫)

Set all constraints for a `Storage`. Can serve as fallback option for all unspecified
subtypes of `Storage`.
"""
function create_node(m, n::Storage, 𝒯, 𝒫)

    # Declaration of the required subsets.
    𝒫ˢᵗᵒʳ = [k for (k,v) ∈ n.Input if v == 1][1]
    𝒫ᵃᵈᵈ  = setdiff(keys(n.Input), [𝒫ˢᵗᵒʳ])
    𝒫ᵉᵐ   = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

    # Constraint for additional required input.
    for p ∈ 𝒫ᵃᵈᵈ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_in][n, t, p] == m[:flow_in][n, t, 𝒫ˢᵗᵒʳ] * n.Input[p])
    end

    # Constraint for storage rate use.
    @constraint(m, [t ∈ 𝒯], m[:stor_rate_use][n, t] == m[:flow_in][n, t, 𝒫ˢᵗᵒʳ])
    @constraint(m, [t ∈ 𝒯], m[:stor_rate_use][n, t] <= m[:stor_rate_inst][n, t])

    # Mass/energy balance constraints for stored energy carrier.
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] <= m[:stor_cap_inst][n, t])
    for t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ t_inv
        if t == first_operational(t_inv)
            if 𝒫ˢᵗᵒʳ ∈ 𝒫ᵉᵐ
                @constraint(m,
                    m[:stor_level][n, t] ==  (m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                             m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ]) * 
                                             t.duration
                    )
                @constraint(m, m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ] >= 0)
            else
                @constraint(m,
                    m[:stor_level][n, t] ==  m[:stor_level][n, last_operational(t_inv)] + 
                                             (m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                             m[:flow_out][n, t , 𝒫ˢᵗᵒʳ]) * 
                                             t.duration
                    )
            end
        else
            if 𝒫ˢᵗᵒʳ ∈ 𝒫ᵉᵐ
                @constraint(m,
                    m[:stor_level][n, t] ==  m[:stor_level][n, previous(t, 𝒯)] + 
                                             (m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                             m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ]) * 
                                             t.duration
                    )
                @constraint(m, m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ] >= 0)
            else
                @constraint(m,
                    m[:stor_level][n, t] ==  m[:stor_level][n, previous(t, 𝒯)] + 
                                             (m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] -
                                             m[:flow_out][n, t , 𝒫ˢᵗᵒʳ]) * 
                                             t.duration
                    )
            end
        end
    end
    
    # Constraint for the emissions, currently hard coded to 0.
    for p_em ∈ 𝒫ᵉᵐ
        if p_em != 𝒫ˢᵗᵒʳ
            @constraint(m, [t ∈ 𝒯],
                m[:emissions_node][n, t, p_em] == 0)
        end
    end

    # Constraint for the variable OPEX contribution.
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum((m[:flow_in][n, t , 𝒫ˢᵗᵒʳ] - m[:emissions_node][n, t, 𝒫ˢᵗᵒʳ])
            * n.Opex_var[t] * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::Sink, 𝒯, 𝒫)

Set all constraints for a `Sink`. Can serve as fallback option for all unspecified
subtypes of `Sink`.
"""
function create_node(m, n::Sink, 𝒯, 𝒫)
    
    # Declaration of the required subsets.
    𝒫ⁱⁿ  = keys(n.Input)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual stream connections.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:flow_in][n, t, p] == m[:cap_use][n, t] * n.Input[p])

    # Constraint for the mass balance allowing surplus and deficit.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] + m[:sink_deficit][n,t] == 
            m[:cap_inst][n, t] + m[:sink_surplus][n,t])

    # Constraint for the emissions associated to using the sink.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * n.Emissions[p_em])

    # Constraint for the variable OPEX contribution.
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum((m[:sink_surplus][n, t] * n.Penalty[:Surplus][t] 
                + m[:sink_deficit][n, t] * n.Penalty[:Deficit][t])
                * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::Availability, 𝒯, 𝒫)
    
Set all constraints for a `Availability`. Can serve as fallback option for all unspecified
subtypes of `Availability`.

Availability nodes can be seen as routing nodes. It is not necessary to have more than one
available node except if one wants to include as well transport between different availability
nodes with associated costs (not implemented at the moment).
"""
function create_node(m, n::Availability, 𝒯, 𝒫)

    # Mass/energy balance constraints for an availability node.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫],
        m[:flow_in][n, t, p] == m[:flow_out][n, t, p])
end

"""
    create_link(m, 𝒯, 𝒫, l, formulation::Formulation)

Set the constraints for a simple `Link` (input = output). Can serve as fallback option for all
unspecified subtypes of `Link`.
"""
function create_link(m, 𝒯, 𝒫, l, formulation::Formulation)
	# Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ link_res(l)],
        m[:link_out][l, t, p] == m[:link_in][l, t, p])
end

"Open topics:
- Emissions associated to usage of the individual energy carriers has to be carefully assessed.
  Currently, this is implemented as fixed emission coefficient for CO2 emissions only based on
  the input. Within storage, this may however not be true.
  As an alternative, we could utilize also a different approach with an updated dictionary in
  which the variables are later changed (mutable structure)
"
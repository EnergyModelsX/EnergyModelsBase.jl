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
    variables_nodes(m, nodes, T, global_data, modeltype)

    # Construction of constraints for the problem
    constraints_node(m, nodes, T, products, links, global_data, modeltype)
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
    variables_nodes(m, 𝒩, 𝒯, global_data::AbstractGlobalData, modeltype::EnergyModel)

Loop through all node types and create variables specific to each type. This is done by
calling the method [`variables_node`](@ref) on all nodes of each type.

The node type representing the widest cathegory will be called first. That is, 
`variables_node` will be called on a `Node`` before it is called and `Network`-nodes.
be called before 
"""
function variables_nodes(m, 𝒩, 𝒯, global_data::AbstractGlobalData, modeltype::EnergyModel)
    # Vector of the unique node types in 𝒩.
    node_composite_types = unique(map(n -> typeof(n), 𝒩))
    # Get all `Node`-types in the type-hierarchy that the nodes 𝒩 represents.
    node_types = collect_node_types(node_composite_types)
    # Sort the node-types such that a supertype will always come its subtypes.
    node_types = sort_node_types(node_types)

    for node_type ∈ node_types
        # All nodes of the given sub type.
        𝒩ˢᵘᵇ = filter(n -> isa(n, node_type), 𝒩)
        # Convert to a Vector of common-type instad of Any.
        𝒩ˢᵘᵇ = convert(Vector{node_type}, 𝒩ˢᵘᵇ)
        try
            variables_node(m, 𝒩ˢᵘᵇ, 𝒯, global_data, modeltype)
        catch LoadError
            # 𝒩ˢᵘᵇ was already registered, by a call to a supertype.
        end
    end
end


"""
    collect_node_types(node_types)

Return a Dict of all the give node_types and their supertypes. The keys in the dictionary
are the types, and their corresponding value is the number in the type hierarchy. 

I.e., Node is at the top and will thus have the value 1. Types just below Node will have
value 2, and so on. 
"""
function collect_node_types(node_types)
    types = Dict()
    for n ∈ node_types
        # Skip the node if we have already traversed its ancestors.
        if n ∈ keys(types)
            continue
        end
        types[n] = 1

        parent = supertype(n)
        if parent == Any
            continue
        end
        
        # If the parent is already added to the list, we can skip it.
        if  parent ∉ node_types
            ancestors = collect_node_types([parent])
            # Increase the rank of the current node by adding the rank of the ancestor with
            # highes rank.
            types[n] += reduce(max, values(ancestors))
            types = merge(types, ancestors)
        end
    end
    return types
end

"""
    sort_node_types(node_types::Dict)

Sort the result of `collect_node_types` and return a vector where a supertype comes before
all its subtypes.
"""
function sort_node_types(node_types::Dict)
    # Find the maximum node-rank, that is the largest number of subtypes from the `Node`
    # type. This is the maximum number stored in the supplied dictionary.
    max_rank = reduce(max, values(node_types))

    # A vector which will contain numbers used to sort the node_types.
    num = []
    for (T, ranking) ∈ node_types
        # Find the number of nodes of type T. The type T with the most nodes will be a
        # broader T, and must be a supertype (or a cousin) of a type with fewer nodes.
        value = length(filter(n -> isa(n, T), keys(node_types)))
        # The ranking is used as the tie-break measure. If we have two types with the same
        # number of nodes, we have to make sure the supertype is sorted before the subtype.
        # The highest rank number must be sorted after the lower one (since this means it is
        # lower in the type hierarchy). Since the value added will only work as a tie break,
        # we make sure it is below 1 by dividing by (max_rank + 1).
        value_ex = value + (1 - ranking / (max_rank + 1))
        push!(num, value_ex)
    end

    # We sort the vector of numbers `num`, and get the indexes of the sorted order.
    sorted_idx = sortperm(num, rev=true)
    # Get the nodes-types from the dictionary as a vector.
    nodes = [n for n in keys(node_types)]
    # Use the indexes of the sorted order to sort the order of the node types.
    sorted_node_types = nodes[sorted_idx]
    return sorted_node_types
end


""""
    variables_node(m, 𝒩ˢᵘᵇ::Vector{<:Node}, 𝒯, global_data::AbstractGlobalData, modeltype::EnergyModel)

Default fallback method when no function is defined for a node type.
"""
function variables_node(m, 𝒩ˢᵘᵇ::Vector{<:Node}, 𝒯, global_data::AbstractGlobalData, modeltype::EnergyModel)
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
    constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, global_data::AbstractGlobalData, modeltype::EnergyModel)

Create link constraints for each `n ∈ 𝒩` depending on its type and calling the function
`create_node(m, n, 𝒯, 𝒫)` for the individual node constraints.

Create constraints for fixed OPEX.
"""
function constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, global_data::AbstractGlobalData, modeltype::EnergyModel)

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
        create_node(m, n, 𝒯, 𝒫, global_data)
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
    create_node(m, n::Source, 𝒯, 𝒫, global_data::AbstractGlobalData)

Set all constraints for a `Source`.
Can serve as fallback option for all unspecified subtypes of `Source`.
"""
function create_node(m, n::Source, 𝒯, 𝒫, global_data::AbstractGlobalData)

    # Declaration of the required subsets.
    𝒫ᵒᵘᵗ = keys(n.Output)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual output stream connections.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:flow_out][n, t, p] == m[:cap_use][n, t] * n.Output[p])

    # Constraint for the maximum capacity.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t])
    
    if hasfield(typeof(n), :Emissions) && !isnothing(n.Emissions)
        # Constraint for the emissions to avoid problems with unconstrained variables.
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * n.Emissions[p_em])
    else
        # Constraint for the emissions associated to using the source.
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_node][n, t, p_em] == 0)
    end

    # Constraint for the variable OPEX contribution.
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::Network, 𝒯, 𝒫, global_data::AbstractGlobalData)

Set all constraints for a `Network`.
Can serve as fallback option for all unspecified subtypes of `Network`.
"""
function create_node(m, n::Network, 𝒯, 𝒫, global_data::AbstractGlobalData)

    # Declaration of the required subsets.
    𝒫ⁱⁿ  = keys(n.Input)
    𝒫ᵒᵘᵗ = keys(n.Output)
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    CO2 = global_data.CO2_instance
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual input stream connections.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ], 
        m[:flow_in][n, t, p] == m[:cap_use][n, t] * n.Input[p])

    # Constraint for the individual output stream connections.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:flow_out][n, t, p] == m[:cap_use][n, t] * n.Output[p])

    # Constraint for the maximum capacity.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t])

    # Constraint for the emissions associated to energy usage
    @constraint(m, [t ∈ 𝒯],
        m[:emissions_node][n, t, CO2] == 
            sum(p_in.CO2_int * m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ))
    
    # Constraint for the other emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ res_not(𝒫ᵉᵐ, CO2)],
        m[:emissions_node][n, t, p_em] == 0)
            
    # Constraint for the variable OPEX contribution.
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::RefNetworkEmissions, 𝒯, 𝒫, global_data::AbstractGlobalData)

Set all constraints for a `RefNetworkEmissions`.
This node is an extension of the `RefNetwork` node including both process emissions and
the potential for CO2 capture.
"""
function create_node(m, n::RefNetworkEmissions, 𝒯, 𝒫, global_data::AbstractGlobalData)

    # Declaration of the required subsets.
    𝒫ⁱⁿ  = keys(n.Input)
    𝒫ᵒᵘᵗ = collect(keys(n.Output))
    𝒫ᵉᵐ  = res_sub(𝒫, ResourceEmit)
    CO2 = global_data.CO2_instance
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraint for the individual input stream connections.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ], 
        m[:flow_in][n, t, p] == m[:cap_use][n, t] * n.Input[p])
            
    # Constraint for the individual output stream connections. Captured CO2 is also included based on
    # the capture rate
    @constraint(m, [t ∈ 𝒯], 
        m[:flow_out][n, t, CO2] == 
            n.CO2_capture * sum(p_in.CO2_int * m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ))
    @constraint(m, [t ∈ 𝒯, p ∈ res_not(𝒫ᵒᵘᵗ, CO2)],
        m[:flow_out][n, t, p] == m[:cap_use][n, t] * n.Output[p])

    # Constraint for the maximum capacity.
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t])
            
    # Constraint for the emissions associated to energy usage
    @constraint(m, [t ∈ 𝒯],
        m[:emissions_node][n, t, CO2] == 
            (1-n.CO2_capture) * sum(p_in.CO2_int * m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ) + 
            m[:cap_use][n, t] * n.Emissions[CO2])

    # Constraint for the other emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ res_not(𝒫ᵉᵐ, CO2)],
        m[:emissions_node][n, t, p_em] == 
            m[:cap_use][n, t] * n.Emissions[p_em])

    # Constraint for the variable OPEX contribution.n
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::Storage, 𝒯, 𝒫, global_data::AbstractGlobalData)

Set all constraints for a `Storage`. Can serve as fallback option for all unspecified
subtypes of `Storage`.
"""
function create_node(m, n::Storage, 𝒯, 𝒫, global_data::AbstractGlobalData)

    # Declaration of the required subsets.
    p_stor = n.Stor_res
    𝒫ᵃᵈᵈ   = setdiff(keys(n.Input), [p_stor])
    𝒫ᵉᵐ    = res_sub(𝒫, ResourceEmit)
    CO2 = global_data.CO2_instance
    𝒯ᴵⁿᵛ   = strategic_periods(𝒯)

    # Constraint for additional required input.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵃᵈᵈ], 
        m[:flow_in][n, t, p] == m[:flow_in][n, t, p_stor] * n.Input[p])

    # Constraint for storage rate use.
    @constraint(m, [t ∈ 𝒯], m[:stor_rate_use][n, t] == m[:flow_in][n, t, p_stor])
    @constraint(m, [t ∈ 𝒯], m[:stor_rate_use][n, t] <= m[:stor_rate_inst][n, t])

    # Constraint for the maximum storage level
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] <= m[:stor_cap_inst][n, t])

    # Mass/energy balance constraints for stored energy carrier.
    for t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ t_inv
        if t == first_operational(t_inv)
            @constraint(m,
                m[:stor_level][n, t] ==  m[:stor_level][n, last_operational(t_inv)] + 
                                            (m[:flow_in][n, t , p_stor] -
                                            m[:flow_out][n, t , p_stor]) * 
                                            t.duration
            )
        else
            @constraint(m,
                m[:stor_level][n, t] ==  m[:stor_level][n, previous(t, 𝒯)] + 
                                            (m[:flow_in][n, t , p_stor] -
                                            m[:flow_out][n, t , p_stor]) * 
                                            t.duration
            )
        end
    end
    
    # Constraint for the emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == 0)

    # Constraint for the variable OPEX contribution.
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum(m[:flow_in][n, t, p_stor] * n.Opex_var[t] * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::RefStorageEmissions, 𝒯, 𝒫, global_data::AbstractGlobalData)

Set all constraints for a `RefStorageEmissions`.
This storage is different to the standard storage as initial and final value differ.
"""
function create_node(m, n::RefStorageEmissions, 𝒯, 𝒫, global_data::AbstractGlobalData)

    # Declaration of the required subsets.
    p_stor = n.Stor_res
    𝒫ᵃᵈᵈ   = setdiff(keys(n.Input), [p_stor])
    𝒫ᵉᵐ    = res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ   = strategic_periods(𝒯)

    # Constraint for additional required input.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵃᵈᵈ], 
        m[:flow_in][n, t, p] == m[:flow_in][n, t, p_stor] * n.Input[p])

    # Constraint for storage rate use.
    @constraint(m, [t ∈ 𝒯], m[:stor_rate_use][n, t] == m[:flow_in][n, t, p_stor])
    @constraint(m, [t ∈ 𝒯], m[:stor_rate_use][n, t] <= m[:stor_rate_inst][n, t])

    # Constraint for the maximum storage level
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] <= m[:stor_cap_inst][n, t])

    # Mass/energy balance constraints for stored energy carrier.
    for t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ t_inv
        if t == first_operational(t_inv)
            @constraint(m,
                m[:stor_level][n, t] ==  (m[:flow_in][n, t , p_stor] -
                                            m[:emissions_node][n, t, p_stor]) * 
                                            t.duration
                )
        else
            @constraint(m,
                m[:stor_level][n, t] ==  m[:stor_level][n, previous(t, 𝒯)] + 
                                            (m[:flow_in][n, t , p_stor] -
                                            m[:emissions_node][n, t, p_stor]) * 
                                            t.duration
                )
        end
    end
    
    # Constraint for the other emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ res_not(𝒫ᵉᵐ, p_stor)],
        m[:emissions_node][n, t, p_em] == 0)

    # Constraint for the variable OPEX contribution.
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum((m[:flow_in][n, t , p_stor] - m[:emissions_node][n, t, p_stor])
            * n.Opex_var[t] * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::Sink, 𝒯, 𝒫, global_data::AbstractGlobalData)

Set all constraints for a `Sink`.
Can serve as fallback option for all unspecified subtypes of `Sink`.
"""
function create_node(m, n::Sink, 𝒯, 𝒫, global_data::AbstractGlobalData)
    
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
                
    if hasfield(typeof(n), :Emissions) && !isnothing(n.Emissions)
        # Constraint for the emissions associated to using the sink.        
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * n.Emissions[p_em])
    else
        # Constraint for the emissions to avoid problems with unconstrained variables.
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_node][n, t, p_em] == 0)
    end

    # Constraint for the variable OPEX contribution.
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum((m[:sink_surplus][n, t] * n.Penalty[:Surplus][t] 
                + m[:sink_deficit][n, t] * n.Penalty[:Deficit][t])
                * t.duration for t ∈ t_inv))
end

"""
    create_node(m, n::Availability, 𝒯, 𝒫, global_data::AbstractGlobalData)
    
Set all constraints for a `Availability`. Can serve as fallback option for all unspecified
subtypes of `Availability`.

Availability nodes can be seen as routing nodes. It is not necessary to have more than one
available node except if one wants to include as well transport between different availability
nodes with associated costs (not implemented at the moment).
"""
function create_node(m, n::Availability, 𝒯, 𝒫, global_data::AbstractGlobalData)

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
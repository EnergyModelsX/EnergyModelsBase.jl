"""
    create_model(case, modeltype::EnergyModel)

Create the model and call all required functions based on provided `modeltype`
and case data.
"""
function create_model(case, modeltype::EnergyModel, m::JuMP.Model)
    @debug "Construct model"

    # WIP Data structure
    𝒯 = case[:T]
    𝒩 = case[:nodes]
    ℒ = case[:links]
    𝒫 = case[:products]

    # Check if the case data is consistent before the model is created.
    check_data(case, modeltype)

    # Declaration of variables for the problem
    variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)
    variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype)
    variables_opex(m, 𝒩, 𝒯, 𝒫, modeltype)
    variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype)
    variables_capacity(m, 𝒩, 𝒯, modeltype)
    variables_nodes(m, 𝒩, 𝒯, modeltype)

    # Construction of constraints for the problem
    constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)
    constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype)
    constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)

    # Construction of the objective function
    objective(m, 𝒩, 𝒯, 𝒫, modeltype)

    return m
end
function create_model(case, modeltype::EnergyModel)
    m = JuMP.Model()
    create_model(case, modeltype::EnergyModel, m)
end

"""
    variables_capacity(m, 𝒩, 𝒯, modeltype::EnergyModel)

Creation of different capacity variables for nodes `𝒩ⁿᵒᵗ` that are neither `Storage`
nor `Availability` nodes. These variables are:
* `:cap_use` - use of a technology node in each operational period
* `:cap_inst` - installed capacity in each operational period in terms of either `:flow_in`
or `:flow_out` (depending on node `n ∈ 𝒩`)

Creation of different storage variables for `Storage` nodes `𝒩ˢᵗᵒʳ`. These variables are:

  * `:stor_level` - storage level at the end of each operational period
  * `:stor_level_Δ_op` - storage level change in each operational period
  * `:stor_level_Δ_rp` - storage level change in each representative period
  * `:stor_rate_use` - storage rate use in each operational period
  * `:stor_cap_inst` - installed capacity for storage in each operational period, constrained
  in the operational case to `n.stor_cap`
  * `:stor_rate_inst` - installed rate for storage, e.g. power in each operational period,
  constrained in the operational case to `n.rate_cap`

"""
function variables_capacity(m, 𝒩, 𝒯, modeltype::EnergyModel)

    𝒩ⁿᵒᵗ = nodes_not_sub(𝒩, Union{Storage, Availability})
    𝒩ˢᵗᵒʳ = filter(is_storage, 𝒩)

    @variable(m, cap_use[𝒩ⁿᵒᵗ, 𝒯] >= 0)
    @variable(m, cap_inst[𝒩ⁿᵒᵗ, 𝒯] >= 0)

    @variable(m, stor_level[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_level_Δ_op[𝒩ˢᵗᵒʳ, 𝒯])
    if 𝒯 isa TwoLevel{S,T,U} where {S,T,U<:RepresentativePeriods}
        𝒯ʳᵖ = repr_periods(𝒯)
        @variable(m, stor_level_Δ_rp[𝒩ˢᵗᵒʳ, 𝒯ʳᵖ])
    end
    @variable(m, stor_rate_use[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_cap_inst[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_rate_inst[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
end

"""
    variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

Declaration of the individual input (`:flow_in`) and output (`:flow_out`) flowrates for
each technological node `n ∈ 𝒩` and link `l ∈ ℒ` (`:link_in` and `:link_out`).
"""
function variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

    𝒩ⁱⁿ  = filter(has_input, 𝒩)
    𝒩ᵒᵘᵗ = filter(has_output, 𝒩)

    @variable(m, flow_in[n_in ∈ 𝒩ⁱⁿ,    𝒯, inputs(n_in)] >= 0)
    @variable(m, flow_out[n_out ∈ 𝒩ᵒᵘᵗ, 𝒯, outputs(n_out)] >= 0)

    @variable(m, link_in[l ∈ ℒ,  𝒯, link_res(l)] >= 0)
    @variable(m, link_out[l ∈ ℒ, 𝒯, link_res(l)] >= 0)
end

"""
    variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

Declaration of emission variables per technology node with emissions `n ∈ 𝒩ᵉᵐ` and emission
resource `𝒫ᵉᵐ ∈ 𝒫`.

The emission variables are differentiated in:
  * `:emissions_node` - emissions of a node in an operational period,
  * `:emissions_total` - total emissions in an operational period, and
  * `:emissions_strategic` - total strategic emissions, constrained to an upper limit \
  based on the field `emission_limit` of the `EnergyModel`.
"""
function variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

    𝒩ᵉᵐ = filter(has_emissions, 𝒩)
    𝒫ᵉᵐ  = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, emissions_node[𝒩ᵉᵐ, 𝒯, 𝒫ᵉᵐ] >= 0)
    @variable(m, emissions_total[𝒯, 𝒫ᵉᵐ] >= 0)
    @variable(m, emissions_strategic[t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ] <=
                emission_limit(modeltype, p, t_inv))
end

"""
    variables_opex(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

Declaration of the OPEX variables (`:opex_var` and `:opex_fixed`) of the model for each
period `𝒯ᴵⁿᵛ ∈ 𝒯`. Variable OPEX can be non negative to account for revenue streams.
"""
function variables_opex(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

    𝒩ⁿᵒᵗ = nodes_not_av(𝒩)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, opex_var[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ])
    @variable(m, opex_fixed[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
end

"""
    variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

Declaration of the CAPEX variables of the model for each investment period `𝒯ᴵⁿᵛ ∈ 𝒯`.
Empty for operational models but required for multiple dispatch in investment model.
"""
function variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
end


"""
    variables_nodes(m, 𝒩, 𝒯, modeltype::EnergyModel)

Loop through all node types and create variables specific to each type. This is done by
calling the method [`variables_node`](@ref) on all nodes of each type.

The node type representing the widest cathegory will be called first. That is,
`variables_node` will be called on a `Node` before it is called on `NetworkNode`-nodes.
"""
function variables_nodes(m, 𝒩, 𝒯, modeltype::EnergyModel)
    # Vector of the unique node types in 𝒩.
    node_composite_types = unique(map(n -> typeof(n), 𝒩))
    # Get all `Node`-types in the type-hierarchy that the nodes 𝒩 represents.
    node_types = collect_types(node_composite_types)
    # Sort the node-types such that a supertype will always come its subtypes.
    node_types = sort_types(node_types)

    for node_type ∈ node_types
        # All nodes of the given sub type.
        𝒩ˢᵘᵇ = filter(n -> isa(n, node_type), 𝒩)
        # Convert to a Vector of common-type instad of Any.
        𝒩ˢᵘᵇ = convert(Vector{node_type}, 𝒩ˢᵘᵇ)
        try
            variables_node(m, 𝒩ˢᵘᵇ, 𝒯, modeltype)
        catch e
            # Parts of the exception message we are looking for.
            pre1 = "An object of name"
            pre2 = "is already attached to this model."
            if isa(e, ErrorException)
                if occursin(pre1, e.msg) && occursin(pre2, e.msg)
                    # 𝒩ˢᵘᵇ was already registered by a call to a supertype, so just continue.
                    continue
                end
            end
            # If we make it to this point, this means some other error occured. This should
            # not be ignored.
            throw(e)
        end
    end
end


""""
    variables_node(m, 𝒩ˢᵘᵇ::Vector{<:Node}, 𝒯, modeltype::EnergyModel)

Default fallback method when no function is defined for a node type.
"""
function variables_node(m, 𝒩ˢᵘᵇ::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
end


"""
    variables_node(m, 𝒩ˢⁱⁿᵏ::Vector{<:Sink}, 𝒯, modeltype::EnergyModel)

Declaration of both surplus (`:sink_surplus`) and deficit (`:sink_deficit`) variables
for `Sink` nodes `𝒩ˢⁱⁿᵏ` to quantify when there is too much or too little energy for
satisfying the demand.
"""
function variables_node(m, 𝒩ˢⁱⁿᵏ::Vector{<:Sink}, 𝒯, modeltype::EnergyModel)
    @variable(m, sink_surplus[𝒩ˢⁱⁿᵏ, 𝒯] >= 0)
    @variable(m, sink_deficit[𝒩ˢⁱⁿᵏ, 𝒯] >= 0)
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
        if has_output(n)
            @constraint(m, [t ∈ 𝒯, p ∈ outputs(n)],
                m[:flow_out][n, t, p] == sum(m[:link_in][l, t, p] for l in ℒᶠʳᵒᵐ if p ∈ inputs(l.to)))
        end
        # Constraint for input flowrate and output links.
        if has_input(n)
            @constraint(m, [t ∈ 𝒯, p ∈ inputs(n)],
                m[:flow_in][n, t, p] == sum(m[:link_out][l, t, p] for l in ℒᵗᵒ if p ∈ outputs(l.from)))
        end
        # Call of function for individual node constraints.
        create_node(m, n, 𝒯, 𝒫, modeltype)
    end

end

"""
    constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

Create constraints for the emissions accounting for both operational and strategic periods.
"""
function constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

    𝒩ᵉᵐ = filter(has_emissions, 𝒩)
    𝒫ᵉᵐ  = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Creation of the individual constraints.
    @constraint(m, con_em_tot[t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_total][t, p] ==
            sum(m[:emissions_node][n, t, p] for n ∈ 𝒩ᵉᵐ)
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ],
        m[:emissions_strategic][t_inv, p] ==
            sum(m[:emissions_total][t, p] * multiple(t_inv, t)
            for t ∈ t_inv)
    )
end

"""
    objective(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

Create the objective for the optimization problem for a given modeltype.
"""
function objective(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒩ⁿᵒᵗ = nodes_not_av(𝒩)
    𝒫ᵉᵐ  = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    opex = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum((m[:opex_var][n, t_inv] + m[:opex_fixed][n, t_inv]) for n ∈ 𝒩ⁿᵒᵗ)
    )

    emissions = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:emissions_strategic][t_inv, p] * emission_price(modeltype, p, t_inv) for p ∈ 𝒫ᵉᵐ)
    )

    # Calculation of the objective function.
    @objective(m, Max,
        -sum((opex[t_inv] + emissions[t_inv]) * duration(t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ)
    )
end

"""
    constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

Call the function `create_link` for link formulation
"""
function constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)
    for l ∈ ℒ
        create_link(m, 𝒯, 𝒫, l, formulation(l))
    end

end

"""
    create_node(m, n::Source, 𝒯, 𝒫, modeltype::EnergyModel)

Set all constraints for a `Source`.
Can serve as fallback option for all unspecified subtypes of `Source`.
"""
function create_node(m, n::Source, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for the outlet flow from the `Source` node
    constraints_flow_out(m, n, 𝒯, modeltype)

    # Call of the function for limiting the capacity to the maximum installed capacity
    constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    create_node(m, n::NetworkNode, 𝒯, 𝒫, modeltype::EnergyModel)

Set all constraints for a `NetworkNode`.
Can serve as fallback option for all unspecified subtypes of `NetworkNode`.
"""
function create_node(m, n::NetworkNode, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for the inlet flow to and outlet flow from the `NetworkNode` node
    constraints_flow_in(m, n, 𝒯, modeltype)
    constraints_flow_out(m, n, 𝒯, modeltype)

    # Call of the function for limiting the capacity to the maximum installed capacity
    constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    create_node(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)

Set all constraints for a `Storage`. Can serve as fallback option for all unspecified
subtypes of `Storage`.
"""
function create_node(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒯ᴵⁿᵛ   = strategic_periods(𝒯)

    # Mass/energy balance constraints for stored energy carrier.
    constraints_level(m, n, 𝒯, 𝒫, modeltype)

    # Call of the function for the inlet flow to the `Storage` node
    constraints_flow_in(m, n, 𝒯, modeltype)

    # Call of the function for limiting the capacity to the maximum installed capacity
    constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    create_node(m, n::Sink, 𝒯, 𝒫, modeltype::EnergyModel)

Set all constraints for a `Sink`.
Can serve as fallback option for all unspecified subtypes of `Sink`.
"""
function create_node(m, n::Sink, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for the inlet flow to the `Sink` node
    constraints_flow_in(m, n, 𝒯, modeltype)

    # Call of the function for limiting the capacity to the maximum installed capacity
    constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    create_node(m, n::Availability, 𝒯, 𝒫, modeltype::EnergyModel)

Set all constraints for a `Availability`. Can serve as fallback option for all unspecified
subtypes of `Availability`.

Availability nodes can be seen as routing nodes. It is not necessary to have more than one
available node except if one wants to include as well transport between different
`Availability` nodes with associated costs (not implemented at the moment).
"""
function create_node(m, n::Availability, 𝒯, 𝒫, modeltype::EnergyModel)

    # Mass/energy balance constraints for an availability node.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫],
        m[:flow_in][n, t, p] == m[:flow_out][n, t, p])
end

"""
    create_link(m, 𝒯, 𝒫, l, formulation::Formulation)

Set the constraints for a simple `Link` (input = output). Can serve as fallback option for
all unspecified subtypes of `Link`.
"""
function create_link(m, 𝒯, 𝒫, l, formulation::Formulation)

	# Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ link_res(l)],
        m[:link_out][l, t, p] == m[:link_in][l, t, p])
end

"""
    create_model(
        case,
        modeltype::EnergyModel,
        m::JuMP.Model;
        check_timeprofiles::Bool = true,
        check_any_data::Bool = true,
    )

Create the model and call all required functions.

## Arguments
- `case` - The case dictionary requiring the keys `:T`, `:nodes`, `:links`, and `products`.
  If the input is not provided in the correct form, the checks will identify the problem.
- `modeltype` - Used modeltype, that is a subtype of the type `EnergyModel`.
- `m` - the empty `JuMP.Model` instance. If it is not provided, then it is assumed that the
  input is a standard `JuMP.Model`.

## Keyword arguments
- `check_timeprofiles=true` - A boolean indicator whether the time profiles of the individual
  nodes should be checked or not. It is advised to not deactivate the check, except if you
  are testing new components. It may lead to unexpected behaviour and potential
  inconsistencies in the input data, if the time profiles are not checked.
- `check_any_data::Bool=true` - A boolean indicator whether the input data is checked or not.
  It is advised to not deactivate the check, except if you are testing new features.
  It may lead to unexpected behaviour and even infeasible models.
"""
function create_model(
    case,
    modeltype::EnergyModel,
    m::JuMP.Model;
    check_timeprofiles::Bool = true,
    check_any_data::Bool = true,
)
    @debug "Construct model"

    # Check if the case data is consistent before the model is created.
    if check_any_data
        check_data(case, modeltype, check_timeprofiles)
    else
        @warn(
            "Checking of the input data is deactivated:\n" *
            "Deactivating the checks for the input data is strongly discouraged. " *
            "It can lead to an infeasible model, if the input data is wrongly specified. " *
            "In addition, even if feasible, weird results can occur.",
            maxlog = 1
        )
    end

    # WIP Data structure
    𝒯 = case[:T]
    𝒩 = case[:nodes]
    ℒ = case[:links]
    𝒫 = case[:products]

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
function create_model(
    case,
    modeltype::EnergyModel;
    check_timeprofiles::Bool = true,
    check_any_data::Bool = true,
)
    m = JuMP.Model()
    create_model(case, modeltype, m; check_timeprofiles, check_any_data)
end

"""
    variables_capacity(m, 𝒩, 𝒯, modeltype::EnergyModel)

Declaration of different capacity variables for nodes `𝒩ⁿᵒᵗ` that are neither `Storage`
nor `Availability` nodes.
These variables are:
* `:cap_use` - use of a technology node in each operational period and
* `:cap_inst` - installed capacity in each operational period in terms of either `:flow_in`
  or `:flow_out` (depending on node `n ∈ 𝒩`)

Declaration of different storage variables for `Storage` nodes `𝒩ˢᵗᵒʳ`.
These variables are:

* `:stor_level` - storage level at the end of each operational period.
* `:stor_level_Δ_op` - storage level change in each operational period.
* `:stor_level_Δ_rp` - storage level change in each representative period. These variables
  are only created if the time structure includes representative periods.
* `:stor_level_Δ_op` - storage level change in each strategic period. These variables are
  optional and created through `SparseVariables`.
* `:stor_level_inst` - installed capacity for storage in each operational period, constrained
  in the operational case to the provided capacity in the [storage parameters](@ref lib-pub-nodes-stor_par)
  used in the field `:level`.
* `:stor_charge_use` - storage charging use in each operational period.
* `:stor_charge_inst` - installed charging capacity, *e.g.*, power, in each operational period,
  constrained in the operational case to the provided capacity in the
  [storage parameters](@ref lib-pub-nodes-stor_par) used in the field `:charge`.
  This variable is only defined if the `Storage` node has a field `charge.`
* `:stor_discharge_use` - storage discharging use in each operational period.
* `:stor_discharge_inst` - installed discharging capacity, *e.g.*, power, in each operational period,
  constrained in the operational case to the provided capacity in the
  [storage parameters](@ref lib-pub-nodes-stor_par) used in the field `:discharge`.
  This variable is only defined if the `Storage` node has a field `discharge.`
"""
function variables_capacity(m, 𝒩, 𝒯, modeltype::EnergyModel)
    𝒩ⁿᵒᵗ = nodes_not_sub(𝒩, Union{Storage,Availability})
    𝒩ˢᵗᵒʳ = filter(is_storage, 𝒩)
    𝒩ˢᵗᵒʳ⁻ᶜ = filter(has_charge, 𝒩ˢᵗᵒʳ)
    𝒩ˢᵗᵒʳ⁻ᵈᶜ = filter(has_discharge, 𝒩ˢᵗᵒʳ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, cap_use[𝒩ⁿᵒᵗ, 𝒯] >= 0)
    @variable(m, cap_inst[𝒩ⁿᵒᵗ, 𝒯] >= 0)

    @variable(m, stor_level[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_level_inst[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_level_Δ_op[𝒩ˢᵗᵒʳ, 𝒯])
    if 𝒯 isa TwoLevel{S,T,U} where {S,T,U<:RepresentativePeriods}
        𝒯ʳᵖ = repr_periods(𝒯)
        @variable(m, stor_level_Δ_rp[𝒩ˢᵗᵒʳ, 𝒯ʳᵖ])
    end
    @variable(m, stor_level_Δ_sp[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ]; container = IndexedVarArray)
    @variable(m, stor_charge_use[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_charge_inst[𝒩ˢᵗᵒʳ⁻ᶜ, 𝒯] >= 0)
    @variable(m, stor_discharge_use[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_discharge_inst[𝒩ˢᵗᵒʳ⁻ᵈᶜ, 𝒯] >= 0)
end

"""
    variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

Declaration of the individual input (`:flow_in`) and output (`:flow_out`) flowrates for
each technological node `n ∈ 𝒩` and link `l ∈ ℒ` (`:link_in` and `:link_out`).
"""
function variables_flow(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)
    𝒩ⁱⁿ = filter(has_input, 𝒩)
    𝒩ᵒᵘᵗ = filter(has_output, 𝒩)

    @variable(m, flow_in[n_in ∈ 𝒩ⁱⁿ, 𝒯, inputs(n_in)] >= 0)
    @variable(m, flow_out[n_out ∈ 𝒩ᵒᵘᵗ, 𝒯, outputs(n_out)] >= 0)

    @variable(m, link_in[l ∈ ℒ, 𝒯, link_res(l)] >= 0)
    @variable(m, link_out[l ∈ ℒ, 𝒯, link_res(l)] >= 0)
end

"""
    variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

Declaration of emission variables per technology node with emissions `n ∈ 𝒩ᵉᵐ` and emission
resource `𝒫ᵉᵐ ∈ 𝒫`.

The emission variables are differentiated in:
* `:emissions_node` - emissions of a node in an operational period,
* `:emissions_total` - total emissions in an operational period, and
* `:emissions_strategic` - total strategic emissions, constrained to an upper limit
  based on the field `emission_limit` of the `EnergyModel`.
"""
function variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
    𝒩ᵉᵐ = filter(has_emissions, 𝒩)
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, emissions_node[𝒩ᵉᵐ, 𝒯, 𝒫ᵉᵐ])
    @variable(m, emissions_total[𝒯, 𝒫ᵉᵐ])
    @variable(m,
        emissions_strategic[t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ] <= emission_limit(modeltype, p, t_inv)
    )
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
function variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel) end

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

"""
    variables_node(m, 𝒩ˢᵘᵇ::Vector{<:Node}, 𝒯, modeltype::EnergyModel)

Default fallback method when no method is defined for a node type.
"""
function variables_node(m, 𝒩ˢᵘᵇ::Vector{<:Node}, 𝒯, modeltype::EnergyModel) end

"""
    variables_node(m, 𝒩ˢⁱⁿᵏ::Vector{<:Sink}, 𝒯, modeltype::EnergyModel)

When the node vector is a `Vector{<:Sink}`, both surplus (`:sink_surplus`) and deficit
(`:sink_deficit`) variables are created to quantify when there is too much or too little
energy for satisfying the demand.
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
                m[:flow_out][n, t, p] ==
                sum(m[:link_in][l, t, p] for l ∈ ℒᶠʳᵒᵐ if p ∈ inputs(l.to))
            )
        end
        # Constraint for input flowrate and output links.
        if has_input(n)
            @constraint(m, [t ∈ 𝒯, p ∈ inputs(n)],
                m[:flow_in][n, t, p] ==
                sum(m[:link_out][l, t, p] for l ∈ ℒᵗᵒ if p ∈ outputs(l.from))
            )
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
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Creation of the individual constraints.
    @constraint(m, con_em_tot[t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_total][t, p] ==
        sum(m[:emissions_node][n, t, p] for n ∈ 𝒩ᵉᵐ)
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ],
        m[:emissions_strategic][t_inv, p] ==
        sum(m[:emissions_total][t, p] * scale_op_sp(t_inv, t) for t ∈ t_inv)
    )
end

"""
    objective(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

Create the objective for the optimization problem for a given modeltype.

The default option includes to the objective function:
- the variable and fixed operating expenses for the individual nodes and
- the cost for the emissions.

The values are not discounted.

This function serve as fallback option if no other method is specified for a specific
`modeltype`.
"""
function objective(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒩ⁿᵒᵗ = nodes_not_av(𝒩)
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    opex = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum((m[:opex_var][n, t_inv] + m[:opex_fixed][n, t_inv]) for n ∈ 𝒩ⁿᵒᵗ)
    )

    emissions = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(
            m[:emissions_strategic][t_inv, p] * emission_price(modeltype, p, t_inv) for
            p ∈ 𝒫ᵉᵐ
        )
    )

    # Calculation of the objective function.
    @objective(m, Max,
        -sum((opex[t_inv] + emissions[t_inv]) * duration_strat(t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ)
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

# Called constraint functions
- [`constraints_data`](@ref) for all `node_data(n)`,
- [`constraints_flow_out`](@ref),
- [`constraints_capacity`](@ref),
- [`constraints_opex_fixed`](@ref), and
- [`constraints_opex_var`](@ref).
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

# Called constraint functions
- [`constraints_data`](@ref) for all `node_data(n)`,
- [`constraints_flow_in`](@ref),
- [`constraints_flow_out`](@ref),
- [`constraints_capacity`](@ref),
- [`constraints_opex_fixed`](@ref), and
- [`constraints_opex_var`](@ref).
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

# Called constraint functions
- [`constraints_level`](@ref)
- [`constraints_data`](@ref) for all `node_data(n)`,
- [`constraints_flow_in`](@ref),
- [`constraints_flow_out`](@ref),
- [`constraints_capacity`](@ref),
- [`constraints_opex_fixed`](@ref), and
- [`constraints_opex_var`](@ref).
"""
function create_node(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Mass/energy balance constraints for stored energy carrier.
    constraints_level(m, n, 𝒯, 𝒫, modeltype)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for the inlet flow to and outlet flow from the `Storage` node
    constraints_flow_in(m, n, 𝒯, modeltype)
    constraints_flow_out(m, n, 𝒯, modeltype)

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

# Called constraint functions
- [`constraints_data`](@ref) for all `node_data(n)`,
- [`constraints_flow_in`](@ref),
- [`constraints_capacity`](@ref),
- [`constraints_opex_fixed`](@ref), and
- [`constraints_opex_var`](@ref).
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

`Availability` nodes can be seen as routing nodes. It is not necessary to have more than one
available node except if one wants to include as well transport between different
`Availability` nodes with associated costs (not implemented at the moment).
"""
function create_node(m, n::Availability, 𝒯, 𝒫, modeltype::EnergyModel)

    # Mass/energy balance constraints for an availability node.
    @constraint(m, [t ∈ 𝒯, p ∈ inputs(n)],
        m[:flow_in][n, t, p] == m[:flow_out][n, t, p]
    )
end

"""
    create_link(m, 𝒯, 𝒫, l, formulation::Formulation)

Set the constraints for a simple `Link` (input = output). Can serve as fallback option for
all unspecified subtypes of `Link`.
"""
function create_link(m, 𝒯, 𝒫, l, formulation::Formulation)

    # Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ link_res(l)],
        m[:link_out][l, t, p] == m[:link_in][l, t, p]
    )
end

"""
    create_model(
        case::EMXCase,
        modeltype::EnergyModel,
        m::JuMP.Model;
        check_timeprofiles::Bool = true,
        check_any_data::Bool = true,
    )

Create the model and call all required functions.

## Arguments
- `case::EMXCase` - The case type represents the chosen time structure, the included
  [`Resource`](@ref)s and the elements and potential coupling between the elements.
  It is explained in more detail in its *[docstring](@ref EMXCase)*.
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

!!! note "Old to new"
    We provide additional methods for translating the old dictionary to the new case types.
"""
function create_model(
    case::EMXCase,
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
    𝒯 = f_time_struct(case)
    𝒫 = f_products(case)
    𝒳 = f_elements_vec(case)
    𝒩 = f_nodes(case)
    ℒ = f_links(case)

    # Declaration of variables for the problem
    for elements ∈ 𝒳
        variables_capacity(m, elements, 𝒯, modeltype)
        variables_flow(m, elements, 𝒯, modeltype)
        variables_opex(m, elements, 𝒯, modeltype)
        variables_capex(m, elements, 𝒯, modeltype)
        variables_emission(m, elements, 𝒫, 𝒯, modeltype)
        variables_elements(m, elements, 𝒯, modeltype)
    end
    variables_emission(m, 𝒫, 𝒯, modeltype)

    # Construction of constraints for the problem
    constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)
    constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype)
    constraints_emissions(m, 𝒳, 𝒫, 𝒯, modeltype)

    # Construction of the objective function
    objective(m, 𝒳, 𝒫, 𝒯, modeltype)

    return m
end
function create_model(
    case::EMXCase,
    modeltype::EnergyModel;
    check_timeprofiles::Bool = true,
    check_any_data::Bool = true,
)
    m = JuMP.Model()
    create_model(case, modeltype, m; check_timeprofiles, check_any_data)
end
function create_model(
    case::Dict,
    modeltype::EnergyModel,
    m::JuMP.Model;
    check_timeprofiles::Bool = true,
    check_any_data::Bool = true,
)
    case_new = EMXCase(case[:T], case[:products], [case[:nodes], case[:links]])
    create_model(case_new, modeltype, m; check_timeprofiles, check_any_data)
end
function create_model(
    case::Dict,
    modeltype::EnergyModel;
    check_timeprofiles::Bool = true,
    check_any_data::Bool = true,
)
    m = JuMP.Model()
    create_model(case, modeltype, m; check_timeprofiles, check_any_data)
end

"""
    variables_capacity(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
    variables_capacity(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)

Declaration of different capacity variables for the element types introduced in
`EnergyModelsBase`. `EnergyModelsBase` introduces two elements for an energy system, and
hence, provides the user with two individual methods:

!!! note "Node variables"
    All nodes, excluding `Storage` and `Availability` nodes have the following capacity
    variables:

    - `cap_use[n, t]` is the capacity utilization of node `n` in operational period `t`.
    - `cap_inst[n, t]` is the installed capacity of node `n` in operational period `t`.

    `Storage` nodes have multiple capacities. The storage level (the amount of mass/energy)
    stored is described through the followign variables

    - `stor_level[n, t]` is the storage level of storage `n` at the end of operational
      period `t`.
    - `stor_level_Δ_op[n, t]` is the storage level change of storage `n` in operational
      period `t`.
    - `stor_level_Δ_rp[n, t_rp]` is the storage level change of storage `n` in representative
      period `t_rp`. These variables are only created if the time structure includes
      representative periods.
    - `stor_level_Δ_sp[n, t_inv]` is storage level change of storage `n` in investment
      period `t_inv`. These variables are optional and created through `SparseVariables`.
      This implies you have to create a method for the function [`variables_node`](@ref) for
      your node type that should use these variables.
    - `stor_level_inst[n, t]` is the installed storage capacity for storage `n` in
      operational period `t`, constrained in the operational case to the provided capacity
      in the [storage parameters](@ref lib-pub-nodes-stor_par) used in the field `:level`.

    The charge capacity variables are describing the charging of a `Storage`:

    - `stor_charge_use[n, t]` is the charging rate of storage `n` in operational period `t`.
    - `stor_charge_inst[n, t]` is the installed charging capacity, *e.g.*, power, of storage
      `n` in operational period `t`, constrained in the operational case to the provided
      capacity in the [storage parameters](@ref lib-pub-nodes-stor_par) used in the field
      `:charge`. This variable is only declared if the `Storage` node has a field `charge`
      and the storage parameters include a capacity.

    The discharge capacity variables are describing the discharging of a `Storage`:

    - `stor_discharge_use[n, t]` is the discharging rate of storage `n` in operational
      period `t`.
    - `stor_discharge_inst[n, t]` is the installed discharging capacity, *e.g.*, power, of
      storage `n` in operational period `t`, constrained in the operational case to the
      provided capacity in the [storage parameters](@ref lib-pub-nodes-stor_par) used in the
      field `:discharge`. This variable is only declared if the `Storage` node has a field
      `discharge` and the storage parameters include a capacity.

!!! tip "Link variables"
    The capacity variables are only created for links, if the function
    [`has_capacity`](@ref) has received an additional method for a given link `l` returning
    the value `true`.

    - `link_cap_inst[l, t]` is the installed capacity of link `l` in operational period `t`.
"""
function variables_capacity(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
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
function variables_capacity(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)
    ℒᶜᵃᵖ = filter(has_capacity, ℒ)

    @variable(m, link_cap_inst[ℒᶜᵃᵖ, 𝒯])
end

"""
    variables_flow(m, _::Vector{<:AbstractElement}, 𝒯, modeltype::EnergyModel)
    variables_flow(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
    variables_flow(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)

Declaration of flow OPEX variables for the element types introduced in
`EnergyModelsBase`. `EnergyModelsBase` introduces two elements for an energy system, and
hence, provides the user with two individual methods:

!!! note "Node variables"
    - `flow_in[n, t, p]` is the flow _**into**_ node `n` in operational period `t` for
      resource `p`. The inflow resources of node `n` are extracted using the function
      [`inputs`](@ref).
    - `flow_out[n, t, p]` is the flow _**from**_ node `n` in operational period `t`
      for resource `p`. The outflow resources of node `n` are extracted using the
      function [`outputs`](@ref).

!!! tip "Link variables"
    - `link_in[n, t]` is the flow _**into**_ link `l` in operational period `t` for
      resource `p`. The inflow resources of link `l` are extracted using the function
      [`inputs`](@ref).
    - `link_out[n, t, p]` is the flow _**from**_ link `l` in operational period `t`
      for resource `p`. The outflow resources of link `l` are extracted using the
      function [`outputs`](@ref).

By default, all nodes `𝒩` and links `ℒ` only allow for unidirectional flow. You can specify
bidirection flow through providing a method to the function [`is_unidirectional`](@ref) for
new link/node types.
"""
function variables_flow(m, _::Vector{<:AbstractElement}, 𝒯, modeltype::EnergyModel) end
function variables_flow(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
    # Extract the nodes with inputs and outputs
    𝒩ⁱⁿ = filter(has_input, 𝒩)
    𝒩ᵒᵘᵗ = filter(has_output, 𝒩)

    # Create the nod flow variables
    @variable(m, flow_in[n_in ∈ 𝒩ⁱⁿ, 𝒯, inputs(n_in)])
    @variable(m, flow_out[n_out ∈ 𝒩ᵒᵘᵗ, 𝒯, outputs(n_out)])

    # Set the bounds for unidirectional nodes
    𝒩ⁱⁿ⁻ᵘⁿⁱ = filter(is_unidirectional, 𝒩ⁱⁿ)
    𝒩ᵒᵘᵗ⁻ᵘⁿⁱ = filter(is_unidirectional, 𝒩ᵒᵘᵗ)

    for n_in ∈ 𝒩ⁱⁿ⁻ᵘⁿⁱ, t ∈ 𝒯, p ∈ inputs(n_in)
        set_lower_bound(m[:flow_in][n_in, t, p], 0)
    end
    for n_out ∈ 𝒩ᵒᵘᵗ⁻ᵘⁿⁱ, t ∈ 𝒯, p ∈ outputs(n_out)
        set_lower_bound(m[:flow_out][n_out, t, p], 0)
    end
end
function variables_flow(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)
    # Create the link flow variables
    @variable(m, link_in[l ∈ ℒ, 𝒯, inputs(l)])
    @variable(m, link_out[l ∈ ℒ, 𝒯, outputs(l)])

    # Set the bounds for unidirectional links
    ℒᵘⁿⁱ = filter(is_unidirectional, ℒ)

    for l ∈ ℒᵘⁿⁱ, t ∈ 𝒯
        for p ∈ inputs(l)
            set_lower_bound(m[:link_in][l, t, p], 0)
        end
        for p ∈ outputs(l)
            set_lower_bound(m[:link_out][l, t, p], 0)
        end
    end
end

"""
    variables_opex(m, _::Vector{<:AbstractElement}, 𝒯, modeltype::EnergyModel)
    variables_opex(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
    variables_opex(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)

Declaration of different OPEX variables for the element types introduced in
`EnergyModelsBase`. `EnergyModelsBase` introduces two elements for an energy system, and
hence, provides the user with two individual methods:

!!! note "Node variables"
    - `opex_var[n, t_inv]` are the variable operating expenses of node `n` in investment
      period `t_inv`. The values can be negative to account for revenue streams
    - `opex_fixed[n, t_inv]` are the fixed operating expenses of node `n` in investment
      period `t_inv`.

!!! tip "Link variables"
    The OPEX variables are only created for links, if the function [`has_opex`](@ref) has
    received an additional method for a given link `l` returning the value `true`.

    - `link_opex_var[n, t_inv]` are the variable operating expenses of link `l` in investment
      period `t_inv`. The values can be negative to account for revenue streams
    - `link_opex_fixed[n, t_inv]` are the fixed operating expenses of node `n` in investment
      period `t_inv`.
"""
function variables_opex(m, _::Vector{<:AbstractElement}, 𝒯, modeltype::EnergyModel) end
function variables_opex(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
    𝒩ⁿᵒᵗ = nodes_not_av(𝒩)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, opex_var[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ])
    @variable(m, opex_fixed[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
end
function variables_opex(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)
    ℒᵒᵖᵉˣ = filter(has_opex, ℒ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, link_opex_var[ℒᵒᵖᵉˣ, 𝒯ᴵⁿᵛ])
    @variable(m, link_opex_fixed[ℒᵒᵖᵉˣ, 𝒯ᴵⁿᵛ] ≥ 0)
end

"""
    variables_capex(m, _::Vector{<:AbstractElement}, 𝒯, modeltype::EnergyModel)
    variables_capex(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
    variables_capex(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)

Declaration of different capital expenditures variables for the element types introduced in
`EnergyModelsBase`. `EnergyModelsBase` introduces two elements for an energy system, and
hence, provides the user with two individual methods:

The default method is empty but it is required for multiple dispatch in investment models.
"""
function variables_capex(m, _::Vector{<:AbstractElement}, 𝒯, modeltype::EnergyModel) end
function variables_capex(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel) end
function variables_capex(m, 𝒩::Vector{<:Link}, 𝒯, modeltype::EnergyModel) end

"""
    variables_emission(m, _::Vector{<:AbstractElement}, 𝒫, 𝒯, modeltype::EnergyModel)
    variables_emission(m, ℒ::Vector{<:Node}, 𝒫, 𝒯, modeltype::EnergyModel)
    variables_emission(m, ℒ::Vector{<:Link}, 𝒫, 𝒯, modeltype::EnergyModel)
    variables_emission(m, 𝒯, 𝒫, modeltype::EnergyModel)

Declaration of emissions variables for the element types introduced in `EnergyModelsBase`
as well as global emission variables. `EnergyModelsBase` introduces two elements for an
energy system, and hence, provides the user with in total three individual methods,
including the global variables:

!!! note "Node variables"
    - `emissions_node[n_em, t, p_em]` are the emissions of node `n_em` with emissions in
      operational period `t` of emission resource `p_em`. The values can be negative to
      account for removal of emissions resources from the environment, through, *e.g.*,
      direct air capture.

!!! tip "Link variables"
    - `emissions_node[n_em, t, p_em]` are the emissions of link `l_em` with emissions in
      operational period `t` of emission resource `p_em`. The values can only be positive as
      links should not allow for removal.

!!! warning "Global variables"
    - `emissions_total[t, p_em]` are the total emissions of in operational period `t` of
      emission resource `p_em`. The values can be negative to account for removal of
      emissions resources from the environment, through, *e.g.*, direct air capture.
    - `emissions_strategic[t_inv, p_em]` are the total emissions of in operational period
      `t` of emission resource `p_em`. The values can be negative to account for removal of
      emissions resources from the environment, through, *e.g.*, direct air capture. The
      variable has an upper bound introduced through the function [`emission_limit`](@ref)
      of the `EnergyModel`.

The inclusion of node and link emissions require that the function `has_emissions` returns
`true` for the given node or link. This is by default achieved for nodes through inclusion
of `EmissionData` in nodes while links require you to explicitly provide a method for your
link type.
"""
function variables_emission(m, _::Vector{<:AbstractElement}, 𝒫, 𝒯, modeltype::EnergyModel) end
function variables_emission(m, 𝒩::Vector{<:Node}, 𝒫, 𝒯, modeltype::EnergyModel)
    𝒩ᵉᵐ = filter(has_emissions, 𝒩)
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)

    @variable(m, emissions_node[𝒩ᵉᵐ, 𝒯, 𝒫ᵉᵐ])
end
function variables_emission(m, ℒ::Vector{<:Link}, 𝒫, 𝒯, modeltype::EnergyModel)
    ℒᵉᵐ = filter(has_emissions, ℒ)
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)

    @variable(m, emissions_link[ℒᵉᵐ, 𝒯, 𝒫ᵉᵐ] ≥ 0)
end
function variables_emission(m, 𝒫, 𝒯, modeltype::EnergyModel)
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, emissions_total[𝒯, 𝒫ᵉᵐ])
    @variable(m,
        emissions_strategic[t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ] <= emission_limit(modeltype, p, t_inv)
    )
end

"""
    variables_elements(m, _::Vector{<:AbstractElement}, 𝒯, modeltype::EnergyModel)
    variables_elements(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
    variables_elements(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)

Loop through all element types and create variables specific to each type. It starts at the
top level and subsequently move through the branches until it reaches a leave. That is,
node nodes, [`variables_node`](@ref) will be called on a
 [`Node`](@ref EnergyModelsBase.Node) before it is called on [`NetworkNode`](@ref)-nodes.

`EnergyModelsBase` provides the user with two element types, [`Link`](@ref) and
[`Node`](@ref EnergyModelsBase.Node):

- `Node` - the subfunction is [`variables_node`](@ref).
- `Link` - the subfunction is [`variables_link`](@ref).
"""
function variables_elements(m, _::Vector{<:AbstractElement}, 𝒯, modeltype::EnergyModel) end
function variables_elements(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
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
function variables_elements(m, ℒ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)
    # Vector of the unique link types in ℒ.
    link_composite_types = unique(map(l -> typeof(l), ℒ))
    # Get all `link`-types in the type-hierarchy that the links ℒ represents.
    link_types = collect_types(link_composite_types)
    # Sort the link-types such that a supertype will always come its subtypes.
    link_types = sort_types(link_types)

    for link_type ∈ link_types
        # All links of the given sub type.
        ℒˢᵘᵇ = filter(l -> isa(l, link_type), ℒ)
        # Convert to a Vector of common-type instad of Any.
        ℒˢᵘᵇ = convert(Vector{link_type}, ℒˢᵘᵇ)
        try
            variables_link(m, ℒˢᵘᵇ, 𝒯, modeltype)
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

Default fallback method when no method is defined for a node type. No variables are created
in this case.
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
    variables_link(m, ℒˢᵘᵇ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)

Default fallback method when no method is defined for a [`Link`](@ref) type.
"""
function variables_link(m, ℒˢᵘᵇ::Vector{<:Link}, 𝒯, modeltype::EnergyModel) end

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
                sum(m[:link_in][l, t, p] for l ∈ ℒᶠʳᵒᵐ if p ∈ outputs(l))
            )
        end
        # Constraint for input flowrate and output links.
        if has_input(n)
            @constraint(m, [t ∈ 𝒯, p ∈ inputs(n)],
                m[:flow_in][n, t, p] ==
                sum(m[:link_out][l, t, p] for l ∈ ℒᵗᵒ if p ∈ inputs(l))
            )
        end
        # Call of function for individual node constraints.
        create_node(m, n, 𝒯, 𝒫, modeltype)
    end
end

"""
    constraints_emissions(m, 𝒳, 𝒫, 𝒯, modeltype::EnergyModel)

Create constraints for the emissions accounting for both operational and strategic periods.
"""
function constraints_emissions(m, 𝒳, 𝒫, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    emissions = JuMP.Containers.DenseAxisArray[]
    for elements ∈ 𝒳
        push!(emissions, emissions_operational(m, elements, 𝒫ᵉᵐ, 𝒯, modeltype))
    end

    # Creation of the individual constraints.
    @constraint(m, con_em_tot[t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_total][t, p] ==
            sum(emission_type[t, p] for emission_type ∈ emissions)
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ],
        m[:emissions_strategic][t_inv, p] ==
            sum(m[:emissions_total][t, p] * scale_op_sp(t_inv, t) for t ∈ t_inv)
    )
end
"""
    emissions_operational(m, elements, 𝒫ᵉᵐ, 𝒯, modeltype::EnergyModel)

Create JuMP expressions indexed over the operational periods `𝒯` for different elements.
The expressions correspond to the total emissions of a given type.

By default, objective expressions are included for:
- `elements = 𝒩::Vector{<:Node}`. In the case of a vector of nodes, the function returns the
  sum of the emissions of all nodes whose method of the function [`has_emissions`](@ref)
  returns true. These nodes should be automatically identified without user intervention.
- `elements = 𝒩::Vector{<:Link}`. In the case of a vector of links, the function returns the
  sum of the emissions of all links whose method of the function [`has_emissions`](@ref)
  returns true.
"""
function emissions_operational(m, 𝒩::Vector{<:Node}, 𝒫ᵉᵐ, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒩ᵉᵐ = filter(has_emissions, 𝒩)

    return @expression(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        sum(m[:emissions_node][n, t, p] for n ∈ 𝒩ᵉᵐ)
    )
end
function emissions_operational(m, ℒ::Vector{<:Link}, 𝒫ᵉᵐ, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    ℒᵉᵐ = filter(has_emissions, ℒ)

    return @expression(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        sum(m[:emissions_link][l, t, p] for l ∈ ℒᵉᵐ)
    )
end

"""
    objective(m, 𝒳, 𝒫, 𝒯, modeltype::EnergyModel)

Create the objective for the optimization problem for a given modeltype.

The default option includes to the objective function:
- the variable and fixed operating expenses for the individual nodes,
- the variable and fixed operating expenses for the individual links, and
- the cost for the emissions.

The values are not discounted.

This function serve as fallback option if no other method is specified for a specific
`modeltype`.
"""
function objective(m, 𝒳, 𝒫, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    opex = JuMP.Containers.DenseAxisArray[]
    for elements ∈ 𝒳
        push!(opex, objective_operational(m, elements, 𝒯ᴵⁿᵛ, modeltype))
    end
    push!(opex, objective_operational(m, 𝒫, 𝒯ᴵⁿᵛ, modeltype))

    # Calculation of the objective function.
    @objective(m, Max,
        -sum(
            sum(elements[t_inv] for elements ∈ opex) * duration_strat(t_inv)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
    )
end
"""
    objective_operational(m, elements, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::EnergyModel)

Create JuMP expressions indexed over the investment periods `𝒯ᴵⁿᵛ` for different elements.
The expressions correspond to the operational expenses of the different elements.
The expressions are not discounted and do not take the duration of the investment periods
into account.

By default, objective expressions are included for:
- `elements = 𝒩::Vector{<:Node}`. In the case of a vector of nodes, the function returns the
  sum of the variable and fixed OPEX for all nodes whose method of the function [`has_opex`](@ref)
  returns true.
- `elements = 𝒩::Vector{<:Link}`. In the case of a vector of links, the function returns the
  sum of the variable and fixed OPEX for all links whose method of the function [`has_opex`](@ref)
  returns true.
- `elements = 𝒩::Vector{<:Resource}`. In the case of a vector of resources, the function
  returns the costs associated to the emissions using the function [`emission_price`](@ref).

!!! note "Default function"
    It is also possible to provide a tuple `𝒳` for only operational or only investment
    objective contributions. In this situation, the expression returns a value of 0 for all
    investment periods.
"""
function objective_operational(
    m,
    𝒩::Vector{<:Node},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒩ⁿᵒᵗ = nodes_not_av(𝒩)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum((m[:opex_var][n, t_inv] + m[:opex_fixed][n, t_inv]) for n ∈ 𝒩ⁿᵒᵗ)
    )
end
function objective_operational(
    m,
    ℒ::Vector{<:Link},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    ℒᵒᵖᵉˣ = filter(has_opex, ℒ)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum((m[:link_opex_var][l, t_inv] + m[:link_opex_fixed][l, t_inv]) for l ∈ ℒᵒᵖᵉˣ)
    )
end
function objective_operational(
    m,
    𝒫::Vector{<:Resource},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(
            m[:emissions_strategic][t_inv, p] * emission_price(modeltype, p, t_inv) for
            p ∈ 𝒫ᵉᵐ
        )
    )
end
objective_operational(m, _, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, _::EnergyModel) =
    @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)

"""
    constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)

Call the function [`create_link`](@ref) for link formulation.
"""
function constraints_links(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)
    for l ∈ ℒ
        create_link(m, 𝒯, 𝒫, l, modeltype, formulation(l))
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
    create_link(m, 𝒯, 𝒫, l::Link, formulation::Formulation)

Set the constraints for a simple `Link` (input = output). Can serve as fallback option for
all unspecified subtypes of `Link`.

All links with capacity, as indicated through the function [`has_capacity`](@ref) call
furthermore the function [`constraints_capacity_installed`](@ref) for limiting the capacity
to the installed capacity.
"""
function create_link(m, 𝒯, 𝒫, l::Link, modeltype::EnergyModel, formulation::Formulation)

    # Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ link_res(l)],
        m[:link_out][l, t, p] == m[:link_in][l, t, p]
    )

    # Call of the function for limiting the capacity to the maximum installed capacity
    if has_capacity(l)
        constraints_capacity_installed(m, l, 𝒯, modeltype)
    end
end

"""
    create_model(
        case::Case,
        modeltype::EnergyModel,
        m::JuMP.Model;
        check_timeprofiles::Bool = true,
        check_any_data::Bool = true,
    )

Create the model and call all required functions.

## Arguments
- `case::Case` - The case type represents the chosen time structure, the included
  [`Resource`](@ref)s and the 𝒳 and potential coupling between the 𝒳.
  It is explained in more detail in its *[docstring](@ref Case)*.
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
    case::Case,
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

    # Extract the information from the `Case`
    𝒯 = get_time_struct(case)
    𝒫 = get_products(case)
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    𝒳_𝒳 = get_couplings(case)

    # Declaration of element variables and constraints of the problem
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        variables_capacity(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒯, modeltype)
        variables_flow(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype)
        variables_opex(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒯, modeltype)
        variables_capex(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒯, modeltype)
        variables_emission(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype)
        variables_elements(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒯, modeltype)
        variables_element_ext_data(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒯, 𝒫, modeltype)

        constraints_elements(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype)
    end

    # Declaration of coupling constraints of the problem
    for couple ∈ 𝒳_𝒳
        elements_vec = [cpl(case) for cpl ∈ couple]
        constraints_couple(m, elements_vec..., 𝒫, 𝒯, modeltype)
    end

    # Declaration of global vairables and constraints
    variables_emission(m, 𝒫, 𝒯, modeltype)
    constraints_emissions(m, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype)

    # Construction of the objective function
    objective(m, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype)

    return m
end
function create_model(
    case::Case,
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
    case_new = Case(case[:T], case[:products], [case[:nodes], case[:links]])
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
    variables_capacity(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    variables_capacity(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

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
function variables_capacity(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    𝒩ᶜᵃᵖ = filter(has_capacity, 𝒩)
    𝒩ˢᵗᵒʳ = filter(is_storage, 𝒩)
    𝒩ˢᵗᵒʳ⁻ᶜ = filter(has_charge, 𝒩ˢᵗᵒʳ)
    𝒩ˢᵗᵒʳ⁻ᵈᶜ = filter(has_discharge, 𝒩ˢᵗᵒʳ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, cap_use[𝒩ᶜᵃᵖ, 𝒯] >= 0)
    @variable(m, cap_inst[𝒩ᶜᵃᵖ, 𝒯] >= 0)

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
function variables_capacity(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    ℒᶜᵃᵖ = filter(has_capacity, ℒ)

    @variable(m, link_cap_inst[ℒᶜᵃᵖ, 𝒯])
end

"""
    variables_flow(m, 𝒳::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    variables_flow(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    variables_flow(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of flow variables for the element types introduced in `EnergyModelsBase`.
`EnergyModelsBase` introduces two elements for an energy system, and hence, provides the
user with two individual methods:

!!! note "Node variables"
    - `flow_in[n, t, p]` is the flow _**into**_ node `n` in operational period `t` for
      resource `p`. The inflow resources of node `n` are extracted using the function
      [`inputs`](@ref).
    - `flow_out[n, t, p]` is the flow _**from**_ node `n` in operational period `t`
      for resource `p`. The outflow resources of node `n` are extracted using the
      function [`outputs`](@ref).
    - call of the function [`variables_flow_resource`](@ref) for introducing resource
      specific flow variables.

!!! tip "Link variables"
    - `link_in[l, t, p]` is the flow _**into**_ link `l` in operational period `t` for
      resource `p`. The inflow resources of link `l` are extracted using the function
      [`inputs`](@ref).
    - `link_out[l, t, p]` is the flow _**from**_ link `l` in operational period `t`
      for resource `p`. The outflow resources of link `l` are extracted using the
      function [`outputs`](@ref).
    - call of the function [`variables_flow_resource`](@ref) for introducing resource
      specific flow variables.

By default, all nodes `𝒩` and links `ℒ` only allow for unidirectional flow. You can specify
bidirectional flow through providing a method to the function [`is_unidirectional`](@ref)
for new link/node types.

The fallback solution for `𝒳::Vector{<:AbstractElement}` is in the current stage included
to maintain backwards compatibility for packages that introduce additional [`AbstractElement`](@ref)s.
"""
function variables_flow(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    # Extract the nodes with inputs and outputs
    𝒩ⁱⁿ = filter(has_input, 𝒩)
    𝒩ᵒᵘᵗ = filter(has_output, 𝒩)

    # Create the node flow variables
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

    # Create new flow variables for specific resource types
    for p_sub ∈ res_types_vec(𝒫)
        variables_flow_resource(m, 𝒩, p_sub, 𝒯, modeltype)
    end

end
function variables_flow(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
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

    # Create new flow variables for specific resource types
    for p_sub ∈ res_types_vec(𝒫)
        variables_flow_resource(m, ℒ, p_sub, 𝒯, modeltype)
    end
end
variables_flow(m, 𝒳::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel) =
    variables_flow(m, 𝒳, 𝒳ᵛᵉᶜ, 𝒯, modeltype)

"""
    variables_flow_resource(m, ℒ::Vector{<:Link}, 𝒫::Vector{<:Resource}, 𝒯, modeltype::EnergyModel)
    variables_flow_resource(m, 𝒩::Vector{<:Node}, 𝒫::Vector{<:Resource}, 𝒯, modeltype::EnergyModel)

Create resource-specific flow variables for links or nodes.

This function is called from [`variables_flow`](@ref) for each subset of resources
sharing the same type. It can be used to add variables and bounds for specialized
resource classes while keeping the default flow variables unchanged.

The default methods are empty and intended to be implemented in extension packages.
"""
function variables_flow_resource(m, ℒ::Vector{<:Link}, 𝒫::Vector{<:Resource}, 𝒯, modeltype::EnergyModel) end
function variables_flow_resource(m, 𝒩::Vector{<:Node}, 𝒫::Vector{<:Resource}, 𝒯, modeltype::EnergyModel) end

"""
    variables_opex(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    variables_opex(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of different OPEX variables for the element types introduced in
`EnergyModelsBase`. `EnergyModelsBase` introduces two elements for an energy system, and
hence, provides the user with two individual methods:

!!! note "Node variables"
    The OPEX variables are only created for nodes, if the function [`has_opex(n::Node)`](@ref)
    has received an additional method for a given nodes `n` returning the value `true`.
    By default, this corresponds to all nodes except for [`Availability`](@ref) nodes.

    - `opex_var[n, t_inv]` are the variable operating expenses of node `n` in investment
      period `t_inv`. The values can be negative to account for revenue streams
    - `opex_fixed[n, t_inv]` are the fixed operating expenses of node `n` in investment
      period `t_inv`.

!!! tip "Link variables"
    The OPEX variables are only created for links, if the function [`has_opex(l::Link)`](@ref)
    has received an additional method for a given link `l` returning the value `true`.

    - `link_opex_var[n, t_inv]` are the variable operating expenses of link `l` in investment
      period `t_inv`. The values can be negative to account for revenue streams
    - `link_opex_fixed[n, t_inv]` are the fixed operating expenses of node `n` in investment
      period `t_inv`.
"""
function variables_opex(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    𝒩ᵒᵖᵉˣ = filter(has_opex, 𝒩)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, opex_var[𝒩ᵒᵖᵉˣ, 𝒯ᴵⁿᵛ])
    @variable(m, opex_fixed[𝒩ᵒᵖᵉˣ, 𝒯ᴵⁿᵛ] >= 0)
end
function variables_opex(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    ℒᵒᵖᵉˣ = filter(has_opex, ℒ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, link_opex_var[ℒᵒᵖᵉˣ, 𝒯ᴵⁿᵛ])
    @variable(m, link_opex_fixed[ℒᵒᵖᵉˣ, 𝒯ᴵⁿᵛ] ≥ 0)
end

"""
    variables_capex(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    variables_capex(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of different capital expenditures variables for the element types introduced in
`EnergyModelsBase`. `EnergyModelsBase` introduces two elements for an energy system, and
hence, provides the user with two individual methods:

The default method is empty but it is required for multiple dispatch in investment models.
"""
function variables_capex(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel) end
function variables_capex(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel) end

"""
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
function variables_emission(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    𝒩ᵉᵐ = filter(has_emissions, 𝒩)
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)

    @variable(m, emissions_node[𝒩ᵉᵐ, 𝒯, 𝒫ᵉᵐ])
end
function variables_emission(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
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
    variables_elements(m, 𝒳::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Loop through all element subtypes and create variables specific to each subtype. It starts
at the top level and subsequently move through the branches until it reaches a leave.

That is, for nodes, [`variables_element`](@ref) will be called on a [`Node`](@ref EnergyModelsBase.Node)
before it is called on [`NetworkNode`](@ref)-nodes.

The function subsequently calls the subroutine [`variables_element`](@ref) for creating the
variables only for a subset of the elements.
"""
function variables_elements(m, 𝒳::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    # Vector of the unique node types in 𝒩.
    element_composite_types = unique(map(x -> typeof(x), 𝒳))
    # Get all `Node`-types in the type-hierarchy that the nodes 𝒩 represents.
    element_types = collect_types(element_composite_types)
    # Sort the node-types such that a supertype will always come its subtypes.
    element_types = sort_types(element_types)

    for element_type ∈ element_types
        # All nodes of the given sub type.
        𝒳ˢᵘᵇ = filter(n -> isa(n, element_type), 𝒳)
        # Convert to a Vector of common-type instad of Any.
        𝒳ˢᵘᵇ = convert(Vector{element_type}, 𝒳ˢᵘᵇ)
        try
            variables_element(m, 𝒳ˢᵘᵇ, 𝒯, modeltype)
        catch e
            # Parts of the exception message we are looking for.
            pre1 = "An object of name"
            pre2 = "is already attached to this model."
            if isa(e, ErrorException)
                if occursin(pre1, e.msg) && occursin(pre2, e.msg)
                    # 𝒳ˢᵘᵇ was already registered by a call to a supertype, so just continue.
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
    variables_element_ext_data(m, 𝒳::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒯, 𝒫,modeltype::EnergyModel)

Loop through all data subtypes and create variables specific to each subtype. It starts
at the top level and subsequently move through the branches until it reaches a leave.

The function subsequently calls the subroutine [`variables_ext_data`](@ref) for creating the
variables for the nodes that have the corresponding data types.
"""
function variables_element_ext_data(
    m,
    𝒳::Vector{<:AbstractElement},
    𝒳ᵛᵉᶜ,
    𝒯,
    𝒫,
    modeltype::EnergyModel
)
    # Extract all ExtensionData types within all elements
    𝒟 = reduce(vcat, [element_data(x) for x ∈ 𝒳])

    # Skip if no data is added to the individual elements
    isempty(𝒟) && return

    # Vector of the unique data types in 𝒟.
    data_composite_types = unique(typeof.(𝒟))
    # Get all `ExtensionData`-types in the type-hierarchy that the nodes 𝒟 represents.
    data_types = collect_types(data_composite_types)
    # Sort the `ExtensionData`-types such that a supertype will always come before its subtypes.
    data_types = sort_types(data_types)

    for data_type ∈ data_types
        # All elements with the given data sub type.
        𝒳ᵈᵃᵗ = filter(x -> any(isa.(element_data(x), data_type)), 𝒳)
        try
            variables_ext_data(m, data_type, 𝒳ᵈᵃᵗ, 𝒯, 𝒫, modeltype)
        catch e
            # Parts of the exception message we are looking for
            pre1 = "An object of name"
            pre2 = "is already attached to this model."
            if isa(e, ErrorException)
                if occursin(pre1, e.msg) && occursin(pre2, e.msg)
                    # data_type was already registered by a call to a supertype, so just continue.
                    continue
                end
            end
            # If we make it to this point, this means some other error occured.
            # This should not be ignored.
            throw(e)
        end
    end
end

"""
    variables_element(m, 𝒩ˢᵘᵇ::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
    variables_element(m, ℒˢᵘᵇ::Vector{<:Link}, 𝒯, modeltype::EnergyModel)

Default fallback method for a vector of elements if no other method is defined for a given
vector of element subtypes. This function calls subfunctions to maintain backwards
compatibility and simplify the differentiation in extension packages.

`EnergyModelsBase` provides the user with two element types, [`Link`](@ref) and
[`Node`](@ref EnergyModelsBase.Node):

- `Node` - the subfunction is [`variables_node`](@ref).
- `Link` - the subfunction is [`variables_link`](@ref).
"""
variables_element(m, 𝒩ˢᵘᵇ::Vector{<:Node}, 𝒯, modeltype::EnergyModel) =
    variables_node(m, 𝒩ˢᵘᵇ, 𝒯, modeltype)
variables_element(m, ℒˢᵘᵇ::Vector{<:Link}, 𝒯, modeltype::EnergyModel) =
    variables_link(m, ℒˢᵘᵇ, 𝒯, modeltype)

"""
    variables_ext_data(m, _::Type{<:ExtensionData}, 𝒳::Vector{<:AbstractElement}, 𝒯, 𝒫, modeltype::EnergyModel)

Default fallback method for the variables creation for a data type of a `Vector{<:AbstractElement}`
`𝒳` if no other method is defined. The default method does not specify any variables.

!!! warning
    The function is called for each individual subtype of [`AbstractElement`](@ref). As a
    consequence, methods, and hence, variables for [`Node`](@ref)s and [`Link`](@ref)s must
    be specified specifically.
"""
function variables_ext_data(
    m,
    _::Type{<:ExtensionData},
    𝒳::Vector{<:AbstractElement},
    𝒯,
    𝒫,
    modeltype::EnergyModel
)
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

Default fallback method when no method is defined for a [`Link`](@ref) type. No variables
are created in this case.
"""
function variables_link(m, ℒˢᵘᵇ::Vector{<:Link}, 𝒯, modeltype::EnergyModel) end

"""
    constraints_elements(m, 𝒳::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)

Loop through all entries of the elements vector and call the subfunction
[`create_element`](@ref) for creating the internal constraints of the entries of the
elements vector.
"""
function constraints_elements(m, 𝒳::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    for x ∈ 𝒳
        create_element(m, x, 𝒯, 𝒫, modeltype)
    end
end

"""
    create_element(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel)
    create_element(m, l::Link, 𝒯, 𝒫, modeltype::EnergyModel)

Calls the create functions for the specific elements to add element specific constraints (by
calling individual subfunctions) and add resource specific constraints by calling
[`constraints_resource`](@ref).

`EnergyModelsBase` provides the user with two element types, [`Link`](@ref) and
[`Node`](@ref EnergyModelsBase.Node):

- `Node` - the subfunction is [`create_node`](@ref).
- `Link` - the subfunction is [`create_link`](@ref).
"""
function create_element(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel)

    create_node(m, n, 𝒯, 𝒫, modeltype)

    # Constraints based on the resource types
    node_resources = Vector{Resource}(unique(vcat(inputs(n), outputs(n))))
    for 𝒫ˢᵘᵇ ∈ res_types_vec(node_resources)
        constraints_resource(m, n, 𝒯, 𝒫ˢᵘᵇ, modeltype)
    end
end

function create_element(m, l::Link, 𝒯, 𝒫, modeltype::EnergyModel)

    create_link(m, l, 𝒯, 𝒫, modeltype)

    # Constraints based on the resource types
    for 𝒫ˢᵘᵇ ∈ res_types_vec(link_res(l))
        constraints_resource(m, l, 𝒯, 𝒫ˢᵘᵇ, modeltype)
    end
end

"""
    constraints_resource(m, n::Node, 𝒯, 𝒫::Vector{<:Resource}, modeltype::EnergyModel)
    constraints_resource(m, l::Link, 𝒯, 𝒫::Vector{<:Resource}, modeltype::EnergyModel)

Create constraints for the flow of resources through an [`AbstractElement`](@ref) for
specific resource types. In `EnergyModelsBase`, this method is provided for
[`Node`](@ref EnergyModelsBase.Node) and [`Link`](@ref).

The function is empty by default and can be implemented in extension packages.
"""
function constraints_resource(m, n::Node, 𝒯, 𝒫::Vector{<:Resource}, modeltype::EnergyModel) end
function constraints_resource(m, l::Link, 𝒯, 𝒫::Vector{<:Resource}, modeltype::EnergyModel) end

"""
    constraints_couple(m, 𝒩::Vector{<:Node}, ℒ::Vector{<:Link}, 𝒫, 𝒯, modeltype::EnergyModel)
    constraints_couple(m, ℒ::Vector{<:Link}, 𝒩::Vector{<:Node}, 𝒫, 𝒯, modeltype::EnergyModel)

Create the couple constraints in `EnergyModelsBase`.

Only couplings between two types are introducded in energy models base. A fallback solution
is available for the coupling between [`AbstractElement`](@ref)s while a method is implemented
for the coupling between a [`Link`](@ref) and a [`Node`](@ref EnergyModelsBase.Node).
"""
function constraints_couple(m, 𝒩::Vector{<:Node}, ℒ::Vector{<:Link}, 𝒫, 𝒯, modeltype::EnergyModel)
    for n ∈ 𝒩
        ℒᶠʳᵒᵐ, ℒᵗᵒ = link_sub(ℒ, n)

        # Constraint for output flowrate and input links.
        if has_output(n)
            @constraint(m, [t ∈ 𝒯, p ∈ outputs(n)],
                m[:flow_out][n, t, p] ==
                sum(m[:link_in][l, t, p] for l ∈ ℒᶠʳᵒᵐ if p ∈ inputs(l))
            )
        end

        # Constraint for input flowrate and output links.
        if has_input(n)
            @constraint(m, [t ∈ 𝒯, p ∈ inputs(n)],
                m[:flow_in][n, t, p] ==
                sum(m[:link_out][l, t, p] for l ∈ ℒᵗᵒ if p ∈ outputs(l))
            )
        end
    end

    # Create new constraints for specific resource types
    for p_sub ∈ res_types_vec(𝒫)
        constraints_couple_resource(m, 𝒩, ℒ, p_sub, 𝒯, modeltype)
    end
end
function constraints_couple(m, ℒ::Vector{<:Link}, 𝒩::Vector{<:Node}, 𝒫, 𝒯, modeltype::EnergyModel)
    return constraints_couple(m, 𝒩, ℒ, 𝒫, 𝒯, modeltype)
end

"""
    constraints_couple_resource(m, 𝒩::Vector{<:Node}, ℒ::Vector{<:Link}, 𝒫::Vector{<:Resource}, 𝒯, modeltype::EnergyModel)

Create resource-specific coupling constraints between nodes and links.

This function is called from [`constraints_couple`](@ref) for each subset of resources
sharing the same type. It can be used to add additional coupling constraints for
specialized resource classes while keeping the default node-link flow balance unchanged.

The default method is empty and intended to be implemented in extension packages.
"""
function constraints_couple_resource(m, 𝒩::Vector{<:Node}, ℒ::Vector{<:Link}, 𝒫::Vector{<:Resource}, 𝒯, modeltype::EnergyModel) end

"""
    constraints_emissions(m, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)

Create constraints for the emissions accounting for both operational and strategic periods.
"""
function constraints_emissions(m, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒫ᵉᵐ = filter(is_resource_emit, 𝒫)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    emissions = JuMP.Containers.DenseAxisArray[]
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        push!(emissions, emissions_operational(m, 𝒳, 𝒫ᵉᵐ, 𝒯, modeltype))
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
    emissions_operational(m, 𝒳, 𝒫ᵉᵐ, 𝒯, modeltype::EnergyModel)

Create JuMP expressions indexed over the operational periods `𝒯` for different elements 𝒳.
The expressions correspond to the total emissions of a given element type.

By default, emissions expressions are included for:
- `𝒳 = 𝒩::Vector{<:Node}`. In the case of a vector of nodes, the function returns the
  sum of the emissions of all nodes whose method of the function [`has_emissions`](@ref)
  returns true. These nodes should be automatically identified without user intervention.
- `𝒳 = 𝒩::Vector{<:Link}`. In the case of a vector of links, the function returns the
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
    objective(m, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)

Create the objective for the optimization problem for a given modeltype.

The default option includes to the objective function:
- the variable and fixed operating expenses for the individual nodes,
- the variable and fixed operating expenses for the individual links, and
- the cost for the emissions.

The values are not discounted.

This function serve as fallback option if no other method is specified for a specific
`modeltype`.
"""
function objective(m, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    opex = JuMP.Containers.DenseAxisArray[]
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        push!(opex, objective_operational(m, 𝒳, 𝒯ᴵⁿᵛ, modeltype))
    end
    push!(opex, objective_operational(m, 𝒫, 𝒯ᴵⁿᵛ, modeltype))

    # Calculation of the objective function.
    @objective(m, Max,
        -sum(
            sum(𝒳[t_inv] for 𝒳 ∈ opex) * duration_strat(t_inv)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
    )
end

"""
    objective_operational(m, 𝒳, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::EnergyModel)

Create JuMP expressions indexed over the investment periods `𝒯ᴵⁿᵛ` for different elements 𝒳.
The expressions correspond to the operating expenses of the different elements.
The expressions are not discounted and do not take the duration of the investment periods
into account.

By default, objective expressions are included for:
- `𝒳 = 𝒩::Vector{<:Node}`. In the case of a vector of nodes, the function returns the
  sum of the variable and fixed OPEX for all nodes whose method of the function [`has_opex`](@ref)
  returns true.
- `𝒳 = 𝒩::Vector{<:Link}`. In the case of a vector of links, the function returns the
  sum of the variable and fixed OPEX for all links whose method of the function [`has_opex`](@ref)
  returns true.
- `𝒳 = 𝒩::Vector{<:Resource}`. In the case of a vector of resources, the function
  returns the costs associated to the emissions using the function [`emission_price`](@ref).

!!! note "Default function"
    It is also possible to provide a tuple `𝒳ᵛᵉᶜ` for only operational or only investment
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
    𝒩ᵒᵖᵉˣ = filter(has_opex, 𝒩)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum((m[:opex_var][n, t_inv] + m[:opex_fixed][n, t_inv]) for n ∈ 𝒩ᵒᵖᵉˣ)
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
            m[:emissions_total][t, p] * emission_price(modeltype, p, t) *
            scale_op_sp(t_inv, t) for t ∈ t_inv, p ∈ 𝒫ᵉᵐ
        )
    )
end

objective_invest(m, _, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, _::AbstractInvestmentModel) =
    @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)

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
    create_link(m, l::Link, 𝒯, 𝒫, modeltype::EnergyModel)
    create_link(m, l::Direct, 𝒯, 𝒫, modeltype::EnergyModel)
    create_link(m, 𝒯, 𝒫, l::Link, modeltype::EnergyModel, formulation::Formulation)

Set the constraints for a `Link`.

!!! note "Deprecated arguments order"
    The argument order `(m, 𝒯, 𝒫, l::Link, modeltype::EnergyModel, formulation::Formulation)`
    is deprecated. It will be removed in the near future. It remains to provide the user
    with the potential for a simple adjustment of the links
"""
function create_link(m, l::Link, 𝒯, 𝒫, modeltype::EnergyModel)
    @warn(
        "`create_link(m, 𝒯, 𝒫, l::Link, modeltype::EnergyModel, formulation::Formulation)` " *
        "is deprecated, use `create_link(m, l::Link, 𝒯, 𝒫, modeltype::EnergyModel)` instead.",
        maxlog = 1
    )
    return create_link(m, 𝒯, 𝒫, l, modeltype, formulation(l))
end
function create_link(m, l::Direct, 𝒯, 𝒫, modeltype::EnergyModel)
    # Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ link_res(l)],
        m[:link_out][l, t, p] == m[:link_in][l, t, p]
    )
end
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

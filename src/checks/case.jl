"""
    check_case_data(case, modeltype::EnergyModel, check_timeprofiles::Bool)

Checks the `case` dictionary is in the correct format.

## Checks
- The individual elements vector must be unique, that it is not possible to have two vector
  of nodes within the elements vector.
- Check that the coupling functions do return elements and not only an empty vector
- Call of [`check_resources`](@ref) for every resource type segment
  ([`res_types_vec`](@ref)) of the products of the case.
"""
function check_case_data(case, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    get_vect_type(vec::Vector{T}) where {T} = T
    vec_types = [get_vect_type(x) for x ∈ 𝒳ᵛᵉᶜ]

    for type_1 ∈ vec_types
        for type_2 ∈ vec_types
            if type_1 ≠ type_2
                @assert_or_log(
                    !(type_1 <: type_2),
                    "It is not possible to have both `$(type_1)` and `$(type_2)` vectors in the case file."
                )
            end
        end
    end

    𝒳ᵛᵉᶜ_𝒳ᵛᵉᶜ = get_couplings(case)
    for couple ∈ 𝒳ᵛᵉᶜ_𝒳ᵛᵉᶜ
        for cpl ∈ couple
            @assert_or_log(
                !isempty(cpl(case)),
                "The function `$cpl` in the couplings field returns an empty vector."
            )
        end
    end

    # Check the resources of the case per resource family
    for 𝒫ˢᵘᵇ ∈ res_types_vec(get_products(case))
        check_resources(case, 𝒫ˢᵘᵇ, modeltype, check_timeprofiles)
    end
end

"""
    check_resources(case, 𝒫ˢᵘᵇ::Vector{<:Resource}, modeltype::EnergyModel, check_timeprofiles::Bool)

Check the resources `𝒫ˢᵘᵇ` of a single resource type segment ([`res_types_vec`](@ref)) of
the `case`.

The default method does not check anything; extension packages that introduce resource types
provide methods for their resource types.
"""
function check_resources(
    case,
    𝒫ˢᵘᵇ::Vector{<:Resource},
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    return nothing
end

"""
    check_elements(log_by_element, _::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_elements(log_by_element, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_elements(log_by_element, ℒ::Vector{<:Link},𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Checks the individual elements vector. It has implemented methods for both `Vector{<:Node}`
and Vector{<:Link}.


!!! note "Node methods"
    All nodes are checked through the functions
    - [`check_node`](@ref) to identify problematic input,
    - [`check_node_data`](@ref EnergyModelsBase.check_node_data(n::Node, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool))
      issues in the provided additional data, and
    - [`check_time_structure`](@ref) to identify time profiles at the highest level that
      are not equivalent to the provided timestructure.

!!! note "Links methods"
    All links are checked through the functions
    - [`check_link`](@ref) to identify problematic input,
    - [`check_link_data`](@ref EnergyModelsBase.check_link_data(l::Link, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool))
      to identify issues in the provided additional data, and
    - [`check_time_structure`](@ref) to identify time profiles at the highest level that
      are not equivalent to the provided timestructure.

    In addition, all links are directly checked:

    - The nodes in the fields `:from` and `:to` are present in the Node vector as extracted
      through the function [`get_nodes`](@ref).
    - The node in the field `:from` has output and the node in the field `:to` has input.
    - The [`inputs`](@ref) of the link are included in the [`outputs`](@ref) of the `:from`
      node and the [`outputs`](@ref) of the link are included in the [`inputs`](@ref) of the
      `:to` node.
"""
function check_elements(
    log_by_element,
    _::Vector{<:AbstractElement},
    𝒳ᵛᵉᶜ,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
end
function check_elements(
    log_by_element,
    𝒩::Vector{<:Node},
    𝒳ᵛᵉᶜ,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
    for n ∈ 𝒩
        # Empty the logs list before each check.
        global logs = []
        check_node(n, 𝒯, modeltype, check_timeprofiles)
        for data ∈ node_data(n)
            check_node_data(n, data, 𝒯, modeltype, check_timeprofiles)
        end

        check_timeprofiles && check_time_structure(n, 𝒯)

        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[n] = logs
    end
end
function check_elements(
    log_by_element,
    ℒ::Vector{<:Link},
    𝒳ᵛᵉᶜ,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
    for l ∈ ℒ
        # Empty the logs list before each check.
        global logs = []

        # Check the connections of the link
        𝒩  = get_nodes(𝒳ᵛᵉᶜ)
        @assert_or_log(
            l.from ∈ 𝒩,
            "The node in the field `:from` is not included in the Node vector. As a consequence," *
            "the link would not be utilized in the model."
        )
        @assert_or_log(
            has_output(l.from),
            "The node in the field `:from` does not allow for outputs."
        )
        @assert_or_log(
            all(p_in ∈ outputs(l.from) for p_in ∈ inputs(l)),
            "Not all resources specified as `inputs` of the link are specified as `outputs` " *
            "of the node in the field `:from`. As a consequence, the link could potentially " *
            "be not utilized in the model."
        )
        @assert_or_log(
            l.to ∈ 𝒩,
            "The node in the field `:to` is not included in the Node vector. As a consequence," *
            "the link would not be utilized in the model."
        )
        @assert_or_log(
            has_input(l.to),
            "The node in the field `:to` does not allow for inputs."
        )
        @assert_or_log(
            all(p_out ∈ inputs(l.to) for p_out ∈ outputs(l)),
            "Not all resources specified as `outputs` of the link are specified as `inputs` " *
            "of the node in the field `:to`. As a consequence, the link could potentially " *
            "not be utilized in the model."
        )

        # Check the links, the link data, and the time structure
        check_link(l, 𝒯, modeltype, check_timeprofiles)
        for data ∈ link_data(l)
            check_link_data(l, data, 𝒯, modeltype, check_timeprofiles)
        end
        check_timeprofiles && check_time_structure(l, 𝒯)
        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[l] = logs
    end
end

"""
    check_model(case, modeltype::EnergyModel, check_timeprofiles::Bool)

Checks the `modeltype` .

## Checks
- All `ResourceEmit`s require a corresponding value in the field `emission_limit`.
- The `emission_limit` time profiles cannot have a finer granulation than `StrategicProfile`.

## Conditional checks (if `check_timeprofiles=true`)
- The profiles in `emission_limit` have to have the same length as the number of strategic
  periods.
- The profiles in `emission_price` have to follow the time structure as outlined in
  [`check_profile`](@ref).
"""
function check_model(case, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯 = get_time_struct(case)

    # Check for inclusion of all emission resources
    for p ∈ get_products(case)
        if isa(p, ResourceEmit)
            @assert_or_log(
                haskey(emission_limit(modeltype), p),
                "All `ResourceEmit`s require an entry in the dictionary " *
                "`emission_limit`. For $p there is none."
            )
        end
    end

    for p ∈ keys(emission_limit(modeltype))
        # Check for potential indexing problems
        em_limit = emission_limit(modeltype, p)
        message =
            "are not allowed for the resource `" *
            string(p) *
            "` in the dictionary " *
            "`emission_limit`."
        check_strategic_profile(em_limit, message)

        # Check for the strategic periods
        check_timeprofiles || continue
        check_profile("emission_limit[" * string(p) * "]", em_limit, 𝒯)
    end

    # Check for the strategic periods
    for p ∈ keys(emission_price(modeltype))
        em_price = emission_price(modeltype, p)
        check_timeprofiles || continue
        check_profile("emission_price[" * string(p) * "]", em_price, 𝒯)
    end
end

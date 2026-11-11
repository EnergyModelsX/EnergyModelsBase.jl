"""
    check_node(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the fields of a `Node` corresponds to required structure.

The default approach calls the subroutine [`check_node_default`](@ref) which provides the
user with default checks for [`Source`](@ref), [`NetworkNode`](@ref), [`Availability`](@ref),
[`Storage`](@ref), and [`Sink`](@ref) nodes.

!!! tip "Creating a new node type"
    When developing a new node with new checks, it is important to create a new method for
    `check_node`. You can then call within this function the default tests for the corresponding
    supertype through calling the function [`check_node_default`](@ref).
"""
check_node(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) =
    check_node_default(n, 𝒯, modeltype, check_timeprofiles)

"""
    check_node_default(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that a `Node` node is valid. By default, that does not include
any checks.
"""
function check_node_default(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) end

"""
    check_node_default(n::Availability, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that an `Availability` node is valid. By default, that does not include
any checks.
"""
function check_node_default(n::Availability, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) end

"""
    check_node_default(n::Source, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Subroutine that can be utilized in other packages for incorporating the standard tests for
a [`Source`](@ref) node.

## Checks
- The field `cap` is required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.
- The value of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref).
"""
function check_node_default(n::Source, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        all(outputs(n, p) ≥ 0 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end

"""
    check_node_default(n::NetworkNode, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Subroutine that can be utilized in other packages for incorporating the standard tests for
a [`NetworkNode`](@ref) node.

## Checks
- The field `cap` is required to be non-negative.
- The values of the dictionary `input` are required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.
- The value of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref).
"""
function check_node_default(n::NetworkNode, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        all(inputs(n, p) ≥ 0 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        all(outputs(n, p) ≥ 0 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end

"""
    check_node_default(n::Storage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Subroutine that can be utilized in other packages for incorporating the standard tests for
a [`Storage`](@ref) node.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required
  to be non-negative if the chosen composite type has the field `capacity`.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required
  to be non-negative`.
- The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
  to be non-negative if the chosen composite type has the field `capacity`.
- The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref) for the chosen composite type.
- The values of the dictionary `input` are required to be non-negative.
- The specified storage [`Resource`](@ref) must be included in the dictionary `input`.
- The values of the dictionary `output` are required to be non-negative.
- The specified storage [`Resource`](@ref) must be included in the dictionary `output`.
"""
function check_node_default(n::Storage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    par_charge = charge(n)
    par_level = level(n)
    par_discharge = discharge(n)

    if isa(par_charge, UnionCapacity)
        @assert_or_log(
            all(capacity(par_charge, t) ≥ 0 for t ∈ 𝒯),
            "The charge capacity must be non-negative."
        )
    end
    if isa(par_charge, UnionOpexFixed)
        check_fixed_opex(par_charge, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    @assert_or_log(
        all(capacity(par_level, t) ≥ 0 for t ∈ 𝒯),
        "The level capacity must be non-negative."
    )
    if isa(par_level, UnionOpexFixed)
        check_fixed_opex(par_level, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    if isa(par_discharge, UnionCapacity)
        @assert_or_log(
            all(capacity(par_discharge, t) ≥ 0 for t ∈ 𝒯),
            "The discharge capacity must be non-negative."
        )
    end
    if isa(par_discharge, UnionOpexFixed)
        check_fixed_opex(par_discharge, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    has_input(n) && @assert_or_log(
        all(inputs(n, p) ≥ 0 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    has_input(n) && @assert_or_log(
        storage_resource(n) ∈ inputs(n),
        "The stored resource must be included in the Dictionary `input`."
    )
    has_output(n) && @assert_or_log(
        all(outputs(n, p) ≥ 0 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    has_output(n) && @assert_or_log(
        storage_resource(n) ∈ outputs(n),
        "The stored resource must be included in the Dictionary `output`."
    )
end

"""
    check_node_default(n::Sink, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Subroutine that can be utilized in other packages for incorporating the standard tests for
a [`Sink`](@ref) node.

## Checks
- The field `cap` is required to be non-negative.
- The values of the dictionary `input` are required to be non-negative.
- The dictionary `penalty` is required to have the keys `:deficit` and `:surplus`.
- The sum of the values `:deficit` and `:surplus` in the dictionary `penalty` has to be
  non-negative to avoid an infeasible model.
"""
function check_node_default(n::Sink, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        all(inputs(n, p) ≥ 0 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        :surplus ∈ keys(n.penalty) && :deficit ∈ keys(n.penalty),
        "The entries `:surplus` and `:deficit` are required in the field `penalty`."
    )

    if :surplus ∈ keys(n.penalty) && :deficit ∈ keys(n.penalty)
        @assert_or_log(
            all(surplus_penalty(n, t) + deficit_penalty(n, t) ≥ 0 for t ∈ 𝒯),
            "An inconsistent combination of `:surplus` and `:deficit` leads to an infeasible model."
        )
    end
end


"""
    check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles::Bool)

Checks that the fixed opex value follows the given `TimeStructure`.
This check requires that a function `opex_fixed(n)` is defined for the input `n` which
returns a `TimeProfile`.

## Checks
- The `opex_fixed` time profile cannot have a finer granulation than `StrategicProfile`.

## Conditional checks (if `check_timeprofiles=true`)
- The profiles in `opex_fixed` have to have the same length as the number of strategic
  periods.
"""
function check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles::Bool)
    # Check for potential indexing problems
    message = "are not allowed for the field `opex_fixed`."
    bool_sp = check_strategic_profile(opex_fixed(n), message)

    # Check that the value is positive in all cases
    if bool_sp
        @assert_or_log(
            all(opex_fixed(n, t_inv) ≥ 0 for t_inv ∈ 𝒯ᴵⁿᵛ),
            "The fixed OPEX must be non-negative."
        )
    end
end

"""
    check_node_data(n::Node, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_node_data(n::Node, data::EmissionsData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the included `ExtensionData` types of a `Node` correspond to required structure.

## Checks `EmissionsData`
- Each node can only have a single `EmissionsData`.
- Time profiles for process emissions, if present.
- The value of the field `co2_capture` is required to be in the range ``[0, 1]``, if
  [`CaptureData`](@ref) is used.
"""
check_node_data(n::Node, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) =
    nothing
function check_node_data(
    n::Node,
    data::EmissionsData,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    em_data = filter(data -> typeof(data) <: EmissionsData, node_data(n))
    @assert_or_log(
        length(em_data) ≤ 1,
        "Only one `EmissionsData` can be added to each node."
    )

    # No checks necessary for a standard `EmissionsEnergy`
    isa(data, EmissionsEnergy) && return

    for p ∈ process_emissions(data)
        value = process_emissions(data, p)
        check_timeprofiles || continue
        isa(value, TimeProfile) || continue
        check_profile(string(p) * " process emissions", value, 𝒯)
    end
end
function check_node_data(
    n::Node,
    data::CaptureData,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    em_data = filter(data -> typeof(data) <: EmissionsData, node_data(n))
    @assert_or_log(
        length(em_data) ≤ 1,
        "Only one `EmissionsData` can be added to each node."
    )

    for p ∈ process_emissions(data)
        value = process_emissions(data, p)
        check_timeprofiles || continue
        isa(value, TimeProfile) || continue
        check_profile(string(p) * " process emissions", value, 𝒯)
    end
    @assert_or_log(
        co2_capture(data) ≤ 1,
        "The field `co2_capture` in `CaptureData` must be less or equal to 1."
    )
    @assert_or_log(
        co2_capture(data) ≥ 0,
        "The field `co2_capture` in `CaptureData` must be non-negative."
    )
end

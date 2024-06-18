"""
    EMB.check_node_data(
        n::EMB.Node,
        data::InvestmentData,
        𝒯,
        modeltype::AbstractInvestmentModel,
        check_timeprofiles::Bool
    )

Performs various checks on investment data for standard nodes.

## Checks
- Each node can only have a single `InvestmentData`.
- All checks incorporated in the function [`check_inv_data`](@ref).
"""
function EMB.check_node_data(
    n::EMB.Node,
    data::InvestmentData,
    𝒯,
    modeltype::AbstractInvestmentModel,
    check_timeprofiles::Bool
)

    inv_data = filter(data -> typeof(data) <: InvestmentData, node_data(n))

    @assert_or_log(
        length(inv_data) <= 1,
        "Only one `InvestmentData` can be added to each node."
    )

    check_inv_data(investment_data(data), capacity(n), 𝒯, "", check_timeprofiles)
end
"""
    EMB.check_node_data(
        n::Storage,
        data::InvestmentData,
        𝒯,
        modeltype::AbstractInvestmentModel,
        check_timeprofiles::Bool,
    )

Performs various checks on investment data for standard nodes. It is similar to the standard
check nodes functions, but adds checks on

## Checks
- Each node can only have a single `InvestmentData`.
- The `InvestmentData` must be `StorageInvData`.
- For each individual investment field all checks incorporated in the function
  [`check_inv_data`](@ref).
"""
function EMB.check_node_data(
    n::Storage,
    data::InvestmentData,
    𝒯,
    modeltype::AbstractInvestmentModel,
    check_timeprofiles::Bool
)

    inv_data = filter(data -> typeof(data) <: InvestmentData, node_data(n))

    @assert_or_log(
        length(inv_data) <= 1,
        "Only one InvestmentData can be added to each node"
    )

    @assert_or_log(
        isa(data, StorageInvData),
        "The investment data for a Storage must be of type `StorageInvData`."
    )

    if !isa(data, StorageInvData)
        return
    end

    for cap_fields ∈ fieldnames(typeof(data))
        sub_data = getfield(data, cap_fields)
        isnothing(sub_data) && continue
        check_inv_data(
            sub_data,
            capacity(getproperty(n, cap_fields)),
            𝒯,
            " of field `" * String(cap_fields) * "`",
            check_timeprofiles
        )
    end
end

"""
    check_inv_data(
        inv_data::AbstractInvData,
        capacity_profile::TimeProfile,
        𝒯,
        message::String,
        check_timeprofiles::Bool,
    )

Performs various checks on investment data introduced within EnergyModelsInvestments

## Checks
- For each field with `TimeProfile`:
  - If the `TimeProfile` is a `StrategicProfile`, it will check that the profile is in
    accordance with the `TimeStructure`
  - `TimeProfile`s in `InvestmentData` cannot include `OperationalProfile`,
    `RepresentativeProfile`, or `ScenarioProfile` as this is not allowed through indexing
    on the `TimeProfile`.
- The field `:min_add` has to be less than `:max_add` if the investment mode is given by
  `ContinuousInvestment` or `SemiContiInvestment`.
- Existing capacity cannot be larger than `:max_inst` capacity in the beginning.
  If `NoStartInvData` is used, it also checks that the the `TimeProfile` `capacity_profile`
  is not including `OperationalProfile`, `RepresentativeProfile`, or `ScenarioProfile`
  to avoid indexing problems.
"""
function check_inv_data(
    inv_data::AbstractInvData,
    capacity_profile::TimeProfile,
    𝒯,
    message::String,
    check_timeprofiles::Bool,
)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    t_inv_1 = collect(𝒯)[1]

    # Check on the individual time profiles
    for field_name ∈ fieldnames(typeof(inv_data))
        time_profile = getfield(inv_data, field_name)
        if isa(time_profile, Union{Investment, LifetimeMode})
            for sub_field_name ∈ fieldnames(typeof(time_profile))
                sub_time_profile = getfield(time_profile, sub_field_name)
                message = "are not allowed for the field: " * String(field_name) *
                    "of the mode " * String(sub_field_name) *
                    "in the investment data" * message * "."
                if isa(sub_time_profile, StrategicProfile) && check_timeprofiles
                    @assert_or_log(
                        length(sub_time_profile.vals) == length(𝒯ᴵⁿᵛ),
                        "Field `" * string(sub_field_name) * "` does not match the strategic structure."
                    )
                end
                EMB.check_strategic_profile(sub_time_profile, message)
            end
        end
        !isa(time_profile, TimeProfile) && continue
        isa(time_profile, FixedProfile) && continue
        message = "are not allowed for the field: " * String(field_name) *
            "in the investment data" * message * "."

        if isa(time_profile, StrategicProfile) && check_timeprofiles
            @assert_or_log(
                length(time_profile.vals) == length(𝒯ᴵⁿᵛ),
                "Field `" * string(field_name) * "` does not match the strategic " *
                "structure in the investment data" * message * "."
            )
        end
        EMB.check_strategic_profile(time_profile, message)
    end

    # Check on the initial capacity in the first strategic period
    if isa(inv_data, StartInvData)
            @assert_or_log(
                inv_data.initial <= max_installed(inv_data, t_inv_1),
                "The starting value in the investment data " * message *
                " can not be larger than the maximum installed constraint."
            )
    else
        message = "are not allowed for the capacity of the investment data " * message *
            ", if investments are allowed and the chosen investment type is `NoStartInvData`."
        EMB.check_strategic_profile(capacity_profile, message)

        @assert_or_log(
            capacity_profile[t_inv_1] <= max_installed(inv_data, t_inv_1),
            "The existing capacity can not be larger than the maximum installed value in " *
            " the first strategic period for the capacity coupled to the investment data" *
            message * "."
        )
    end

    # Check on the minmimum and maximum added capacities
    if isa(investment_mode(inv_data), Union{ContinuousInvestment, SemiContiInvestment})
        @assert_or_log(
            sum(min_add(inv_data, t) ≤ max_add(inv_data, t) for t ∈ 𝒯) == length(𝒯),
            "`min_add` has to be less than `max_add` in the investment data" *
            message * "."
        )
    end
end

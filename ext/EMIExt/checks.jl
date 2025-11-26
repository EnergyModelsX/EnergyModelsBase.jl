"""
    EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)
    EMB.check_node_data(n::Storage, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)

Performs various checks on investment data for standard and [`Storage`](@ref) nodes.

## Checks for standard nodes
- Each node can only have a single `InvestmentData`.
- All checks incorporated in the function [`check_inv_data`](@ref).

## Checks for [`Storage`](@ref) nodes
- Each node can only have a single `InvestmentData`.
- The `InvestmentData` must be `StorageInvData`.
- For each individual investment field all checks incorporated in the function
  [`check_inv_data`](@ref).
"""
function EMB.check_node_data(
    n::EMB.Node,
    data::InvestmentData,
    𝒯,
    modeltype::AbstractInvestmentModel,
    check_timeprofiles::Bool,
)
    inv_data = filter(data -> typeof(data) <: InvestmentData, node_data(n))

    @assert_or_log(
        length(inv_data) ≤ 1,
        "Only one `InvestmentData` can be added to each node."
    )

    check_inv_data(EMI.investment_data(data), EMB.capacity(n), 𝒯, "", check_timeprofiles)
end
function EMB.check_node_data(
    n::Storage,
    data::InvestmentData,
    𝒯,
    modeltype::AbstractInvestmentModel,
    check_timeprofiles::Bool,
)
    inv_data = filter(data -> typeof(data) <: InvestmentData, node_data(n))

    @assert_or_log(
        length(inv_data) ≤ 1,
        "Only one InvestmentData can be added to each node"
    )

    @assert_or_log(
        isa(data, StorageInvData),
        "The investment data for a Storage must be of type `StorageInvData`."
    )

    if !isa(data, StorageInvData)
        return
    end

    cap_map = Dict(:charge => charge, :level => level, :discharge => discharge)

    for (cap, cap_fun) ∈ cap_map
        sub_data = getfield(data, cap)
        isnothing(sub_data) && continue
        check_inv_data(
            sub_data,
            EMB.capacity(cap_fun(n)),
            𝒯,
            " of field `" * String(cap) * "`",
            check_timeprofiles,
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
    bool_sp = true

    # Check on the individual time profiles
    for field_name ∈ fieldnames(typeof(inv_data))
        time_profile = getfield(inv_data, field_name)
        if isa(time_profile, Union{Investment,LifetimeMode})
            for sub_field_name ∈ fieldnames(typeof(time_profile))
                sub_time_profile = getfield(time_profile, sub_field_name)
                submessage =
                    "are not allowed for the field `" * String(sub_field_name) *
                    "` of the mode `" * String(field_name) *
                    "` in the investment data" * message * "."
                if isa(sub_time_profile, StrategicProfile) && check_timeprofiles
                    @assert_or_log(
                        length(sub_time_profile.vals) == length(𝒯ᴵⁿᵛ),
                        "Field `" * string(sub_field_name) *
                        "` does not match the strategic structure."
                    )
                end
                EMB.check_strategic_profile(sub_time_profile, submessage)
            end
        end
        !isa(time_profile, TimeProfile) && continue
        isa(time_profile, FixedProfile) && continue
        submessage =
            "are not allowed for the field `" * String(field_name) *
            "` in the investment data" * message * "."

        if isa(time_profile, StrategicProfile) && check_timeprofiles
            @assert_or_log(
                length(time_profile.vals) == length(𝒯ᴵⁿᵛ),
                "Field `" * string(field_name) * "` does not match the strategic " *
                "structure in the investment data" * message * "."
            )
        end
        if field_name == :initial
            bool_sp = EMB.check_strategic_profile(time_profile, submessage)
        else
            EMB.check_strategic_profile(time_profile, submessage)
        end
    end

    # Check on the initial capacity in the first strategic period
    if isa(inv_data, StartInvData)
        if bool_sp
            @assert_or_log(
                all(inv_data.initial[t_inv] ≤ EMI.max_installed(inv_data, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ),
                "The value for the field `initial` in the investment data " * message *
                " can not be larger than the maximum installed constraint."
            )
        end
    else
        submessage =
            "are not allowed for the capacity of the investment data " * message *
            ", if investments are allowed and the chosen investment type is `NoStartInvData`."
        bool_sp = EMB.check_strategic_profile(capacity_profile, submessage)
        if bool_sp
            @assert_or_log(
                all(capacity_profile[t_inv] ≤ EMI.max_installed(inv_data, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ),
                "The existing capacity can not be larger than the maximum installed value in " *
                "all strategic periods for the capacity coupled to the investment data " *
                message * "."
            )
        end
    end

    # Check on the minmimum and maximum added capacities
    if isa(EMI.investment_mode(inv_data), Union{ContinuousInvestment,SemiContiInvestment})
        @assert_or_log(
            all(EMI.min_add(inv_data, t) ≤ EMI.max_add(inv_data, t) for t ∈ 𝒯),
            "`min_add` has to be less than `max_add` in the investment data " *
            message * "."
        )
    end
end

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
  - If the `TimeProfile` is a `StrategicProfile` or `StrategicStochasticProfile`, it will
    check that the profile is in accordance with the `TimeStructure`
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
    bool = false        # Boolean for subprofile checks
    bool_sp = true      # Boolean

    # Check on the individual time profiles
    for field_name ∈ fieldnames(typeof(inv_data))
        tp = getfield(inv_data, field_name)
        if isa(tp, Union{Investment,LifetimeMode})
            for sub_field_name ∈ fieldnames(typeof(tp))
                stp = getfield(tp, sub_field_name)
                submessage =
                    "are not allowed for the field `" * String(sub_field_name) *
                    "` of the mode `" * String(field_name) *
                    "` in the investment data" * message * "."
                if (isa(stp, StrategicProfile) || isa(stp, StrategicStochasticProfile)) &&
                    check_timeprofiles
                    EMB.check_profile(string(sub_field_name), stp, 𝒯; bool)
                end
                EMB.check_strategic_profile(stp, submessage)
            end
        end
        (!isa(tp, TimeProfile) || isa(tp, FixedProfile)) && continue
        submessage =
            "are not allowed for the field `" * String(field_name) *
            "` in the investment data" * message * "."

        if (isa(tp, StrategicProfile) || isa(tp, StrategicStochasticProfile)) &&
            check_timeprofiles
            EMB.check_profile(string(field_name), tp, 𝒯; bool)
        end
        if field_name == :initial || field_name == :max_inst
            bool_sp *= EMB.check_strategic_profile(tp, submessage)
        else
            EMB.check_strategic_profile(tp, submessage)
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
        bool_sp *= EMB.check_strategic_profile(capacity_profile, submessage)
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

"""
    EMB.check_link_data(l::Link, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)

Performs various checks on investment data for [`Link`](@ref)s.

## Checks for standard nodes
- Each link can only have a single `InvestmentData`.
- All checks incorporated in the function [`check_inv_data`](@ref).
"""
function EMB.check_link_data(
    l::Link,
    data::InvestmentData,
    𝒯,
    modeltype::AbstractInvestmentModel,
    check_timeprofiles::Bool,
)
    inv_data = filter(data -> typeof(data) <: InvestmentData, link_data(l))

    @assert_or_log(
        length(inv_data) ≤ 1,
        "Only one `InvestmentData` can be added to each node."
    )

    check_inv_data(EMI.investment_data(data), EMB.capacity(l), 𝒯, "", check_timeprofiles)
end

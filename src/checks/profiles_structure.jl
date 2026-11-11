"""
    check_time_structure(x::AbstractElement, 𝒯)

Check that all fields of a `AbstractElement` that are of type `TimeProfile` correspond to
the time structure `𝒯`.
"""
function check_time_structure(x::AbstractElement, 𝒯)
    for fieldname ∈ fieldnames(typeof(x))
        value = getfield(x, fieldname)
        if isa(value, TimeProfile)
            check_profile(fieldname, value, 𝒯)
        end
    end
end

"""
    check_profile(fieldname, value::TimeProfile, 𝒯::TwoLevel; bool::Bool=true)
    check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevel; bool::Bool=true)
    check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::TwoLevel; bool::Bool=true)

    check_profile(fieldname, value::TimeProfile, 𝒯::TwoLevelTree; bool::Bool=true)
    check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevelTree; bool::Bool=true)
    check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::TwoLevelTree; bool::Bool=true)

    check_profile(fieldname, value::TimeProfile, 𝒯::Union{SimpleTimes,OperationalScenarios}; bool::Bool=true)
    check_profile(fieldname, value::StrategicProfile, 𝒯::Union{SimpleTimes,OperationalScenarios}; bool::Bool=true)
    check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::Union{SimpleTimes,OperationalScenarios}; bool::Bool=true)

Check that an individual `TimeProfile` corresponds to the time structure `𝒯`. The individual
checks are depending on the profile type and the time structure.

If `𝒯` is a `SimpleTimes` or `OperationalScenarios`, it is treated as a single strategic
period.
`StrategicProfile`s and `StrategicStochasticProfile`s result in a warning, and only their
first profile is checked.

The key word argument `bool` is used to identify whether subprofiles should be checked
(`true` as default) or not (`false`).
"""
function check_profile(fieldname, value::TimeProfile, 𝒯::TwoLevel; bool::Bool=true)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    bool && for t_inv ∈ 𝒯ᴵⁿᵛ
        p_msg = "strategic period $(t_inv.sp)"
        check_profile(fieldname, value, t_inv.operational, p_msg)
    end
end
function check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevel; bool::Bool=true)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    len_vals = length(value.vals)
    len_ts = length(𝒯ᴵⁿᵛ)
    if len_vals > len_ts
        message = "` is longer than the strategic time structure. " *
            "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message = "` is shorter than the strategic time structure. It will use the last " *
            "value for the last $(len_ts - len_vals) strategic period(s)."
    end
    @assert_or_log(
        len_vals == len_ts, "The `TimeProfile` of field `" * string(fieldname) * message
    )
    bool && for t_inv ∈ 𝒯ᴵⁿᵛ
        p_msg = "strategic period $(t_inv.sp)"
        check_profile(
            fieldname,
            value.vals[minimum([t_inv.sp, length(value.vals)])],
            t_inv.operational,
            p_msg,
        )
    end
end
function check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::TwoLevel; bool::Bool=true)
    @warn(
        "Using `StrategicStochasticProfile` with `TwoLevel` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the profiles of the first scenario are used in the model and " *
        "tested.",
        maxlog = 1
    )
    prof = StrategicProfile([op_prof[1] for op_prof ∈ value.vals])
    check_profile(fieldname, prof, 𝒯)
end
function check_profile(fieldname, value::TimeProfile, 𝒯::TwoLevelTree; bool::Bool=true)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    bool && for t_inv ∈ 𝒯ᴵⁿᵛ
        p_msg = "branch $(t_inv.branch) in strategic period $(t_inv.sp)"
        check_profile(fieldname, value, t_inv.operational, p_msg)
    end
end
function check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevelTree; bool::Bool=true)
    𝒯ˢˢᶜ = strategic_scenarios(𝒯)
    t_inv_vec = []

    for ssc ∈ 𝒯ˢˢᶜ
        𝒯ᴵⁿᵛ = strategic_periods(ssc)
        len_vals = length(value.vals)
        len_ts = length(𝒯ᴵⁿᵛ)
        if len_vals > len_ts
            message = "` is longer than strategic scenario $(ssc.scen). " *
                "Its last $(len_vals - len_ts) value(s) will be omitted."
        elseif len_vals < len_ts
            message = "` is shorter than strategic scenario $(ssc.scen). It will use the " *
                "last value for the last $(len_ts - len_vals) strategic period(s)."
        end
        @assert_or_log(
            len_vals == len_ts, "The `TimeProfile` of field `" * string(fieldname) * message,
        )
        bool && for t_inv ∈ 𝒯ᴵⁿᵛ
            t_inv ∈ t_inv_vec && continue
            push!(t_inv_vec, t_inv)

            p_msg = "branch $(t_inv.branch) in strategic period $(t_inv.sp)"
            check_profile(
                fieldname,
                value.vals[minimum([t_inv.sp, length(value.vals)])],
                t_inv.operational,
                p_msg,
            )
        end
    end
end
function check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::TwoLevelTree; bool::Bool=true)
    # Check for the number of strategic periods
    len_vals = length(value.vals)
    len_ts = n_strat_per(𝒯)
    if len_vals > len_ts
        message = "` is longer than the strategic time structure. " *
            "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message = "` is shorter than the strategic time structure. It will use the last " *
            "value for the last $(len_ts - len_vals) strategic period(s)."
    end
    @assert_or_log(
        len_vals == len_ts,
        "The `TimeProfile` of field `" * string(fieldname) * message,
    )

    # Check each individual branch
    for sp ∈ 1:n_strat_per(𝒯)
        pre_msg = "` in strategic period $(sp) has "
        len_vals = length(value.vals[minimum([sp, length(value.vals)])])
        len_branches = n_branches(𝒯, sp)
        if len_vals > len_branches
            message = pre_msg * "more branches than the time structure. " *
                "Its last $(len_vals - len_branches) value(s) will be omitted."
        elseif len_vals < len_branches
            message = pre_msg * "less branches than the time structure. It will use the " *
                "last value for the last $(len_branches - len_vals) branche(s)."
        end
        @assert_or_log(
            len_vals == len_branches,
            "The `TimeProfile` of field `" * string(fieldname) * message,
        )
    end

    # Check the sub profiles
    bool && for t_inv ∈ strategic_periods(𝒯)
        p_msg = "branch $(t_inv.branch) in strategic period $(t_inv.sp)"
        sp_prof = value.vals[minimum([t_inv.sp, length(value.vals)])]
        check_profile(
            fieldname,
            sp_prof[minimum([t_inv.branch, length(sp_prof)])],
            t_inv.operational,
            p_msg,
        )
    end
end
function check_profile(
    fieldname,
    value::TimeProfile,
    𝒯::Union{SimpleTimes,OperationalScenarios};
    bool::Bool=true,
)
    bool && check_profile(fieldname, value, 𝒯, "the time structure")
end
function check_profile(
    fieldname,
    value::StrategicProfile,
    𝒯::Union{SimpleTimes,OperationalScenarios};
    bool::Bool=true,
)
    @warn(
        "Using `StrategicProfile` with `$(nameof(typeof(𝒯)))` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested.",
        maxlog = 1
    )
    bool && check_profile(fieldname, value.vals[1], 𝒯, "the time structure")
end
function check_profile(
    fieldname,
    value::StrategicStochasticProfile,
    𝒯::Union{SimpleTimes,OperationalScenarios};
    bool::Bool=true,
)
    @warn(
        "Using `StrategicStochasticProfile` with `$(nameof(typeof(𝒯)))` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested.",
        maxlog = 1
    )
    bool && check_profile(fieldname, value.vals[1][1], 𝒯, "the time structure")
end

"""
    check_profile(fieldname, value::TimeProfile, ts::TimeStructure, p_msg)

Check that an individual `TimeProfile` corresponds to the time structure `ts` in strategic
period `sp`. The function flow is designed to provide errors in all situations in which the
the `TimeProfile` does not correspond to the chosen `TimeStructure` through the application
of the `@assert_or_log` macro.

Examples for inconsistent combinations:

```julia
ts = SimpleTimes(3, 1)

# A too long OperationalProfile resulting in omitting the last 2 values
value = OperationalProfile([1, 2, 3, 4, 5])

# A too short OperationalProfile resulting in repetition of the last value once
value = OperationalProfile([1, 2])
```

If you use a more detailed `TimeProfile` than the `TimeStructure`, it will provide you with
a warning, *e.g.*, using `RepresentativeProfile` without `RepresentativePeriods`.
"""
function check_profile(fieldname, value::OperationalProfile, ts::SimpleTimes, p_msg)
    len_vals = length(value.vals)
    len_ts = length(ts)
    if len_vals > len_ts
        message =
            "` in " * p_msg * " is longer than the operational time structure. " *
            "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message =
            "` in " * p_msg * " is shorter than the operational time structure. " *
            "It will use the last value for the last $(len_ts - len_vals + 1) " *
            "operational period(s)."
    end
    @assert_or_log(
        len_vals == len_ts,
        "The `TimeProfile` of field `" * string(fieldname) * message
    )
end
function check_profile(fieldname, value::OperationalProfile, ts::OperationalScenarios, p_msg)
    for t_osc ∈ opscenarios(ts)
        p_msg_osc = "operational scenario $(t_osc.scen) in " * p_msg
        check_profile(fieldname, value, t_osc.operational, p_msg_osc)
    end
end
function check_profile(fieldname, value::OperationalProfile, ts::RepresentativePeriods, p_msg)
    for t_rp ∈ repr_periods(ts)
        p_msg_rp = "representative period $(t_rp.rp) in " * p_msg
        check_profile(fieldname, value, t_rp.operational, p_msg_rp)
    end
end

function check_profile(fieldname, value::ScenarioProfile, ts::SimpleTimes, p_msg)
    @warn(
        "Using `ScenarioProfile` with `SimpleTimes` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested.",
        maxlog = 1
    )
    check_profile(fieldname, value.vals[1], ts, p_msg)
end
function check_profile(fieldname, value::ScenarioProfile, ts::OperationalScenarios, p_msg)
    len_vals = length(value.vals)
    len_ts = length(opscenarios(ts))
    if len_vals > len_ts
        message =
            "` in " * p_msg * " is longer than the operational scenario time structure. " *
            "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message =
            "` in " * p_msg * " is shorter than the operational scenario time structure. " *
            "It will use the last value for the last $(len_ts - len_vals + 1) " *
            "operational period(s)."
    end
    @assert_or_log(
        len_vals == len_ts,
        "The `TimeProfile` of field `" * string(fieldname) * message
    )
    for t_osc ∈ opscenarios(ts)
        p_msg_osc = "operational scenario $(t_osc.scen) in " * p_msg
        check_profile(
            fieldname,
            value.vals[minimum([t_osc.scen, length(value.vals)])],
            t_osc.operational,
            p_msg_osc,
        )
    end
end
function check_profile(fieldname, value::ScenarioProfile, ts::RepresentativePeriods, p_msg)
    for t_rp ∈ repr_periods(ts)
        p_msg_rp = "representative period $(t_rp.rp) in " * p_msg
        check_profile(fieldname, value, t_rp.operational, p_msg_rp)
    end
end

function check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, p_msg)
    @warn(
        "Using `RepresentativeProfile` with `SimpleTimes` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested.",
        maxlog = 1
    )
    check_profile(fieldname, value.vals[1], ts, p_msg)
end
function check_profile(fieldname, value::RepresentativeProfile, ts::OperationalScenarios, p_msg)
    @warn(
        "Using `RepresentativeProfile` with `OperationalScenarios` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested.",
        maxlog = 1
    )
    check_profile(fieldname, value.vals[1], ts, p_msg)
end
function check_profile(
    fieldname,
    value::RepresentativeProfile,
    ts::RepresentativePeriods,
    p_msg,
)
    len_vals = length(value.vals)
    len_ts = length(repr_periods(ts))
    if len_vals > len_ts
        message =
        "` in " * p_msg * " is longer than the representative time structure. " *
        "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message =
        "` in " * p_msg * " is shorter than the representative time structure. " *
        "It will use the last value for the last $(len_ts - len_vals + 1) " *
        "operational period(s)."
    end
    @assert_or_log(
        len_vals == len_ts,
        "The `TimeProfile` of field `" * string(fieldname) * message
    )
    for t_rp ∈ repr_periods(ts)
        p_msg_rp = "in representative period $(t_rp.rp) in " * p_msg
        check_profile(
            fieldname,
            value.vals[minimum([t_rp.rp, length(value.vals)])],
            t_rp.operational,
            p_msg_rp,
        )
    end
end
check_profile(fieldname, value, ts, p_msg) = nothing

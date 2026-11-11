"""
    check_not_profile(::Type{TP}, sub_prof::TimeProfile, sub_msg::String) where {TP<:TimeProfile}

Check that the profile `sub_prof` is not of type `TP`.
"""
function check_not_profile(::Type{TP}, sub_prof::TimeProfile, sub_msg::String) where {TP<:TimeProfile}
    bool_tp = !isa(sub_prof, TP)
    @assert_or_log(bool_tp, "`$(TP)`s " * sub_msg)
    return bool_tp
end

"""
    check_sub_profile(::Type{TP}, sub_prof::TimeProfile, sub_msg::String) where {T<:TimeProfile}

Check that the time profile `sub_prof` is applicable for indexing with `TimeStructurePeriod`
or `PeriodPartition` as declared by the time profile type `TP`. The check is not performed
on potential subprofiles. This can be achieved through the function [`check_sub_profs`](@ref)

!!! danger "Usage of this function"
    User should never use this function directly. It should only be included within the core
    structure in `EnergyModelsBase`.
"""
function check_sub_profile(
    ::Type{TP},
    sub_prof::TimeProfile,
    sub_msg::String,
) where  {TP<:Union{StrategicProfile, StrategicStochasticProfile}}
    bool_op = check_not_profile(OperationalProfile, sub_prof, sub_msg)
    bool_part = check_not_profile(PartitionProfile, sub_prof, sub_msg)
    bool_scp = check_not_profile(ScenarioProfile, sub_prof, sub_msg)
    bool_rp = check_not_profile(RepresentativeProfile, sub_prof, sub_msg)

    return bool_op * bool_part * bool_scp * bool_rp
end
function check_sub_profile(
    ::Type{TP},
    sub_prof::TimeProfile,
    sub_msg::String,
) where  {TP<:RepresentativeProfile}
    bool_op = check_not_profile(OperationalProfile, sub_prof, sub_msg)
    bool_part = check_not_profile(PartitionProfile, sub_prof, sub_msg)
    bool_scp = check_not_profile(ScenarioProfile, sub_prof, sub_msg)

    return bool_op * bool_part * bool_scp
end
function check_sub_profile(
    ::Type{TP},
    sub_prof::TimeProfile,
    sub_msg::String,
) where  {TP<:ScenarioProfile}
    bool_op = check_not_profile(OperationalProfile, sub_prof, sub_msg)
    bool_part = check_not_profile(PartitionProfile, sub_prof, sub_msg)

    return bool_op * bool_part
end
function check_sub_profile(
    ::Type{TP},
    sub_prof::TimeProfile,
    sub_msg::String,
) where  {TP<:PartitionProfile}
    bool_op = check_not_profile(OperationalProfile, sub_prof, sub_msg)
    return bool_op
end
function check_sub_profile(
    ::Type{TP},
    sub_prof::Number,
    sub_msg::String,
) where {TP<:PartitionProfile}
    return true
end

"""
    check_sub_profs(check_type::Type{TP_C}, prof::TP, msg::String) where {TP_C<:TimeProfile, TP<:TimeProfile}

Check that the provided `prof` allows indexing as specified through the provided
`TP_C` profile type. Each sub profile is checked if the `prof` includes sub profiles
different than `FixedProfile`. The check is based on the provided profile type `TP_C`.

!!! danger "Usage of these functions"
    User should never use these functions directly. They should only be included within the
    core structure in `EnergyModelsBase`.
"""
function check_sub_profs(::Type{TP_C}, prof::TP_C, msg::String) where {TP_C<:TimeProfile}
    bool_val = true
    sub_msg = "in `$(TP_C)`s " * msg
    for sub_prof ∈ prof.vals
        bool_val *= check_sub_profile(TP_C, sub_prof, sub_msg)
        !bool_val && break
    end
    return bool_val
end
function check_sub_profs(
    ::Type{TP_C},
    prof::TP,
    msg::String,
) where {TP_C<:TimeProfile, TP<:TimeProfile}
    bool_val = true
    sub_msg = "in `$(TP.name.name)`s " * msg
    for sub_prof ∈ prof.vals
        bool_val *= check_sub_profile(TP_C, sub_prof, sub_msg)
        !bool_val && break
        bool_val *= check_sub_profs(TP_C, sub_prof, sub_msg)
        !bool_val && break
    end
    return bool_val
end
function check_sub_profs(
    ::Type{TP_C},
    prof::TP_C,
    msg::String,
) where {TP_C<:StrategicStochasticProfile}
    bool_val = true
    sub_msg = "in `StrategicStochasticProfile`s " * msg
    for sp_array ∈ prof.vals, sub_prof ∈ sp_array
        bool_val = check_sub_profile(TP_C, sub_prof, sub_msg)
        !bool_val && break
    end
    return bool_val
end
function check_sub_profs(
    ::Type{TP_C},
    prof::StrategicStochasticProfile,
    msg::String,
) where {TP_C<:TimeProfile}
    bool_val = true
    sub_msg = "in `StrategicStochasticProfile`s " * msg
    for sp_array ∈ prof.vals, sub_prof ∈ sp_array
        bool_val = check_sub_profile(TP_C, sub_prof, sub_msg)
        !bool_val && break
        bool_val *= check_sub_profs(TP_C, sub_prof, msg)
        !bool_val && break
    end
    return bool_val
end
function check_sub_profs(
    ::Type{TP_C},
    prof::TP,
    msg::String,
) where {TP_C<:TimeProfile, TP<:Union{FixedProfile, Number}}
    return true
end

"""
    check_strategic_profile(time_profile::TimeProfile, message::String)

Function for checking that an individual `TimeProfile` does not include the wrong type for
strategic indexing.

## Checks
- `TimeProfile`s accessed in `StrategicPeriod`s cannot include `OperationalProfile`,
  `PartitionProfile`, `ScenarioProfile`, or `RepresentativeProfile` as this is not allowed
  through indexing on the `TimeProfile`.
"""
function check_strategic_profile(time_profile::TimeProfile, message::String)

    if isa(time_profile, Union{StrategicProfile, StrategicStochasticProfile})
        # Iterate through the strategic or strategic stochstic profiles, if existing
        bool_sp = check_sub_profs(typeof(time_profile), time_profile, message)
    else
        # Check the profiles
        bool_sp = check_sub_profile(StrategicProfile, time_profile, message)
    end

    return bool_sp
end

"""
    check_representative_profile(time_profile::TimeProfile, message::String)

Function for checking that an individual `TimeProfile` does not include the wrong type for
representative periods indexing.

## Input
- `time_profile` - The time profile that should be checked.
- `message` - A message that should be printed after the type of profile.

## Checks
- `TimeProfile`s accessed in `RepresentativePeriod`s cannot include `OperationalProfile`,
  `PartitionProfile` or `ScenarioProfile` as this is not allowed through indexing on the
  `TimeProfile`.
"""
function check_representative_profile(time_profile::TimeProfile, message::String)

    if isa(
        time_profile,
        Union{StrategicProfile, StrategicStochasticProfile, RepresentativeProfile}
    )
        # Iterate through the strategic, strategic stochstic, or representative profiles,
        # if existing
        bool_rp = check_sub_profs(RepresentativeProfile, time_profile, message)
    else
        # Check the profiles
        bool_rp = check_sub_profile(RepresentativeProfile, time_profile, message)
    end
    return bool_rp
end

"""
    check_scenario_profile(time_profile::TimeProfile, message::String)

Function for checking that an individual `TimeProfile` does not include the wrong type for
scenario indexing.

## Checks
- `TimeProfile`s accessed in `OperationalScenario`s cannot include `OperationalProfile` or
  `PartitionProfile` as this is not allowed through indexing on the `TimeProfile`.
"""
function check_scenario_profile(time_profile::TimeProfile, message::String)
    # Check the sub structures
    if isa(
        time_profile,
        Union{StrategicProfile, StrategicStochasticProfile, RepresentativeProfile, ScenarioProfile}
    )
        bool_scp = check_sub_profs(ScenarioProfile, time_profile, message)
    else
        # Check the profiles
        bool_scp = check_sub_profile(ScenarioProfile, time_profile, message)
    end

    return bool_scp
end

"""
    check_partition_profile(time_profile::TimeProfile, message::String)

Function for checking that an individual `TimeProfile` does not include the wrong type for
partition indexing.

## Checks
- `TimeProfile`s accessed in `PeriodPartition`s cannot include `OperationalProfile` as this is
  not allowed through indexing on the `TimeProfile`.
"""
function check_partition_profile(time_profile::TimeProfile, message::String)
    # Check the sub structures
    if isa(
        time_profile,
        Union{StrategicProfile, StrategicStochasticProfile, RepresentativeProfile, ScenarioProfile, PartitionProfile}
    )
        bool_part = check_sub_profs(PartitionProfile, time_profile, message)
    else
        # Check the profiles
        bool_part = check_sub_profile(PartitionProfile, time_profile, message)
    end

    return bool_part
end

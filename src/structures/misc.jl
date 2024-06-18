"""
Union of `Nothing`, `TS.TimePeriod`, and `TS.TimeStructure{T} where {T}` to be used for
limiting the potential entries to the fields of [`PreviousPeriods`](@ref) and
[`CyclicPeriods`](@ref) types.
"""
NothingPeriod = Union{Nothing, TS.TimePeriod, TS.TimeStructure{T}} where {T}

"""
    PreviousPeriods{S<:NothingPeriod, T<:NothingPeriod, U<:NothingPeriod}

Contains the previous strategic, representative, and operational period used through the
application of the `with_prev` iterator developed in `TimeStruct`.

# Fields
- **`sp::S`** the previous strategic period.
- **`rp::T`** the previous representative period.
- **`op::U`** the previous operational period.
"""
struct PreviousPeriods{S<:NothingPeriod, T<:NothingPeriod, U<:NothingPeriod}
    sp::S
    rp::T
    op::U
end

"""
    strat_per(prev_periods::PreviousPeriods)

Extracts the previous strategic period (fields `sp`) from a [`PreviousPeriods`](@ref) type.
"""
strat_per(prev_periods::PreviousPeriods) = prev_periods.sp
"""
    rep_per(prev_periods::PreviousPeriods)

Extracts the previous representative period (fields `sp`) from a [`PreviousPeriods`](@ref) type.
"""
rep_per(prev_periods::PreviousPeriods) = prev_periods.rp
"""
    op_per(prev_periods::PreviousPeriods)

Extracts the previous operational period (fields `sp`) from a [`PreviousPeriods`](@ref) type.
"""
op_per(prev_periods::PreviousPeriods) = prev_periods.op

"""
    CyclicPeriods{S<:NothingPeriod}

Contains information for calculating the cyclic constraints. The parameter `S` should be
either an `AbstractStrategicPeriod` or `AbstractRepresentativePeriod`.

# Fields
- **`last_per::S`** the last period in the case of `S<:AbstractRepresentativePeriod` or the
  current period in the case of `S<:AbstractStrategicPeriod` as the last strategic period
  is not relevant.
- **`current_per::S`** the current period in both the case of `S<:AbstractRepresentativePeriod`
  and `S<:AbstractStrategicPeriod`.
"""
struct CyclicPeriods{S<:NothingPeriod}
    last_per::S
    current_per::S
end

"""
    last_per(cyclic_pers::CyclicPeriods)

Extracts the last period (fields `last_per`) from a [`CyclicPeriods`](@ref) type.
"""
last_per(cyclic_pers::CyclicPeriods) = cyclic_pers.last_per

"""
    current_per(cyclic_pers::CyclicPeriods)

Extracts the current period (fields `current_per`) from a [`CyclicPeriods`](@ref) type.
"""
current_per(cyclic_pers::CyclicPeriods) = cyclic_pers.current_per

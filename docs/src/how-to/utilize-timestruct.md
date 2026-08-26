# [Utilize `TimeStruct`](@id how_to-utilize_TS)

`EnergyModelsBase` uses the package [`TimeStruct`](https://sintefore.github.io/TimeStruct.jl/) to describe time.
[`TimeStruct`](https://sintefore.github.io/TimeStruct.jl/) offers a large variety of options that can appear overwhelming when you first encounter them.
Hence, it is important to highlight how it works and which parameters you may want to analyze.

## [Structures for time description](@id how_to-utilize_TS-struct)

`TimeStruct` introduces individual structures that are used for describing time.
In the following introduction, the most important structures are explained.
There are other structures, but these will be added once `EnergyModelsBase` supports their formulation.

### [Operational periods](@id how_to-utilize_TS-struct-op)

Operational periods correspond to periods in which no investments are allowed.
In general, you can imagine operational periods to be the individual hours you want to model, although it is not limited to hours.
In each operational period, we have an optimal dispatch problem given the constraints.
Operational periods are normally implemented using the type [`SimpleTimes`](@extref TimeStruct.SimpleTimes) which has the following structure:

```julia
op_duration = 1  # Each operational period has a duration of 1
op_number = 24   # There are in total 24 operational periods
operational_periods = SimpleTimes(op_number, op_duration)
```

In the example above, we assume that there are 24 operational periods, each with the same duration, *i.e.*, a duration of 1.
The unit itself is not important, but you can interpret a duration of 1 as one hour.
In this case, the operational periods would correspond to a full day.

!!! note
    All operational periods are continuous. This implies that one is not allowed to have jumps in the representative periods.
    This affects all "dynamic" constraints, that is, constraints where the current operational period is dependent on the previous operational period.
    In `EnergyModelsBase`, this is only the case for the level balance in `RefStorage`.
    Representative periods allow for jumps between operational periods, as outlined below.

Note that `TimeStruct` does not require that each operational period has the same length.
Consider the following example:

```jldoctest test_label; setup = :(using TimeStruct)
op_duration = [4, 2, 1, 1, 2, 4, 2, 1, 1, 2, 4]
op_number = length(op_duration)
operational_periods = SimpleTimes(op_number, op_duration)

# output
SimpleTimes{Int64}(11, [4, 2, 1, 1, 2, 4, 2, 1, 1, 2, 4], 24)
```

In this case, we model the day not at a uniform hourly resolution, but use hourly resolution only in the morning and afternoon.
The night has a reduced time resolution of 4 hours.
However, we still model a full 24 hours, as can be seen from the following command:

```jldoctest test_label; setup = :(using TimeStruct)
TimeStruct._total_duration(operational_periods)

# output
24
```

When using an `Array` as input to [`SimpleTimes`](@extref TimeStruct.SimpleTimes), it is not necessary to specify `op_number`.
Instead, one can also write

```jldoctest test_label; setup = :(using TimeStruct)
operational_periods = SimpleTimes(op_duration)

# output
SimpleTimes{Int64}(11, [4, 2, 1, 1, 2, 4, 2, 1, 1, 2, 4], 24)
```

The constructor automatically deduces that there are 11 operational periods.

[`SimpleTimes`](@extref TimeStruct.SimpleTimes) is also the lowest-level `TimeStructure` present in `TimeStruct`.
It is used in all subsequent structures.
When iterating over a `TimeStructure`, *e.g.*, as `t ∈ operational_periods`, you obtain the single operational periods that are required for solving the optimal dispatch.

!!! warning
    Energy conversion, production, or emissions of a node, as well as all flows, are always defined for a duration of 1 in operational periods.
    You have to be careful when considering the output from the model. The same holds for capacities provided in the input file.

### [Operational scenarios](@id how_to-utilize_TS-struct-scp)

Operational scenarios are introduced through the structure [`OperationalScenarios`](@extref TimeStruct.OperationalScenarios).
They consist of potentially multiple scenarios, each represented by a [`SimpleTimes`](@extref TimeStruct.SimpleTimes) structure and assigned a given probability.

Consider the following example:

```julia
day = SimpleTimes(24, 1)
```

This example can represent a single day with hourly resolution.
In practice, when including the `day` into a [`TwoLevel`](@extref TimeStruct.TwoLevel), it is scaled multiple times.
However, it can lead to an energy system which is only working for the chosen operational time profile for both energy supply and demand.

Operational scenarios can be included through creating multiple instances of [`SimpleTimes`](@extref TimeStruct.SimpleTimes) or by specifying the same [`SimpleTimes`](@extref TimeStruct.SimpleTimes) structure.
The individual constructors are explained in the corresponding docstring of [`OperationalScenarios`](@extref TimeStruct.OperationalScenarios).
The following example includes a `week_1` representing a standard week and a special `week_2` with a lower probability to represent, *e.g.*, a peak demand week in which the energy system is still required to satisfy the overall demand

```julia
week_1 = SimpleTimes(168, 1)
week_2 = SimpleTimes(168, 1)

prob = [0.9, 0.1]          # Probability of the scenarios

oscs = OperationalScenarios([week_1, week_2], prob)
```

Operational scenarios only affect the system if you have different [`OperationalProfile`](@extref TimeStruct.OperationalProfile)s within a [`ScenarioProfile`](@extref TimeStruct.ScenarioProfile).

!!! warning "Scaling of variables"
    The probability of an operational scenario is included when operational variables are linked to representative or strategic variables.
    However, the probability is not included for the individual operational variables as they are unscaled.
    This is also explained in the *[section on optimization variables](@ref man-opt_var)*

### [Representative periods](@id how_to-utilize_TS-struct-rp)

Representative periods are introduced through the structure [`RepresentativePeriods`](@extref TimeStruct.RepresentativePeriods).
Representative periods correspond to a repetition of a set of different periods.

Consider the following example:

```julia
day = SimpleTimes(24, 1)
```

This example can represent a single day with hourly resolution.
In practice, when including the `day` into a [`TwoLevel`](@extref TimeStruct.TwoLevel), it is scaled multiple times.
This can lead to an underestimation of storage requirements and makes it impossible to include seasonal storage.

Representative periods can be included through creating multiple instances of [`SimpleTimes`](@extref TimeStruct.SimpleTimes).
The following example creates two days with hourly resolution, one winter day and one summer day.
These two days are then combined into a [`RepresentativePeriods`](@extref TimeStruct.RepresentativePeriods) structure with 2 periods.
These two periods sum to a duration of 8760, that is, one year.
Each representative period is scaled up `365/2=182.5` times.

```julia
winter_day = SimpleTimes(24, 1)
summer_day = SimpleTimes(24, 1)

periods = 2                 # Number of representative periods
total_duration = 8760       # Total duration
share = [0.5, 0.5]          # Share of the total duration of the representative periods

rps = RepresentativePeriods(periods, total_duration, share, [winter_day, summer_day])
```

Representative periods only affect the system if storage is included.
In the case of storage, this scaling impacts the initial level of the storage in representative periods.
Otherwise, the application of [`SimpleTimes`](@extref TimeStruct.SimpleTimes) suffices.

The individual constructors are explained in the corresponding docstring of [`RepresentativePeriods`](@extref TimeStruct.RepresentativePeriods).

### [Strategic periods](@id how_to-utilize_TS-struct-sp)

Strategic periods are introduced through the structure [`TwoLevel`](@extref TimeStruct.TwoLevel).
They correspond to the periods in which changes in capacity, efficiency, or operational expenditures can occur.
The general structure is given by

```julia
day = SimpleTimes(24, 1)
strategic_duration = 5  # Each strategic period has a duration of 5
strategic_number = 5    # There are in total 5 strategic periods
T = TwoLevel(strategic_number, strategic_duration, day)
```

The example above corresponds to 5 strategic periods, each with a duration of 5. Each strategic period includes 24 operational periods.
One can choose any reference duration for a strategic period and the corresponding duration of an operational period.
In the example above, no link is specified between the duration of 1 for an operational period and the duration of 1 for a strategic period.
In this situation, [`TwoLevel`](@extref TimeStruct.TwoLevel) assumes that the link is 1, meaning that strategic periods and operational periods have the same duration.

In general, it is easiest to use a duration of 1 of a strategic period to be equivalent to a single year while a duration of 1 of an operational period should correspond to 1 hour.
In this case, we have to specify [`TwoLevel`](@extref TimeStruct.TwoLevel) slightly differently:

```julia
𝒯 = TwoLevel(strategic_number, strategic_duration, day; op_per_strat=8760)
```

Note that we used the optional keyword argument `op_per_strat` in this example.
It links the duration 1 of an operational period to the duration 1 of a strategic period.
If we want a duration of 1 in an operational period to correspond to one hour and a duration of 1 in a strategic period to correspond to one year, we need to use the keyword argument `op_per_strat` with a value of `op_per_strat = 365*24 = 8760`.

!!! warning
    It is important to be certain which value one should use for `op_per_strat`. When using the wrong value, one obtains wrong operational results that may affect the analysis.

Similar to the [`SimpleTimes`](@extref TimeStruct.SimpleTimes) structure, it is also possible to have strategic periods of varying durations.
It can be advantageous to, *e.g.*, have a reduced duration in the initial investment periods, while having an increased duration in the latter.
This would allow to reflect the higher uncertainty associated with future decisions and improve computational tractability by reducing model instance size.

You can extract an iterator for the individual strategic periods using the following command:

```julia
𝒯ᴵⁿᵛ = strategic_periods(𝒯)
```

When iterating through 𝒯ᴵⁿᵛ, you obtain the individual strategic periods.
When iterating through a strategic period, you obtain the individual operational periods:

```julia
for t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ t_inv end
# is equivalent to
for t ∈ 𝒯 end
```

The advantage of the first approach is that you can also use the indices of the strategic periods.
However, it may make the code look more complicated, when this is not required.
It does not have any implication on the model building speed and it is up to the user, which approach to choose.

!!! warning
    Fixed operational expenditures and emission limits provided to a model have to be provided for a duration of 1 in the strategic period.

### [Summary](@id how_to-utilize_TS-struct-sum)

In the standard case, it is recommended to use **hour** as duration 1 for an operational period and **year** as duration 1 for a strategic period.
This still allows you to use a higher resolution, *e.g.*, 15 minutes or less, by specifying a duration of 0.25 for these operational periods, while simplifying the overall design.

```julia
day = SimpleTimes(24, 1)
strategic_duration = 5  # Each strategic period has a duration of 5
strategic_number = 5    # There are in total 5 strategic periods
𝒯 = TwoLevel(strategic_number, strategic_duration, day; op_per_strat=8760)
```

This is especially relevant for capacities and emission limits, as well as for analyzing the values obtained from the model.

## [Profiles](@id how_to-utilize_TS-profile)

Profiles are used for providing parameters to the model.
There are five main profiles to consider:

1. [`FixedProfile`](@extref TimeStruct.FixedProfile) represents the same value in all periods,
2. [`OperationalProfile`](@extref TimeStruct.OperationalProfile) represents variations between operational periods,
3. [`ScenarioProfile`](@extref TimeStruct.ScenarioProfile) represents variations between operational scenarios,
4. [`RepresentativeProfile`](@extref TimeStruct.RepresentativeProfile) represents variations between representative periods, and
5. [`StrategicProfile`](@extref TimeStruct.StrategicProfile) represents variations between strategic periods.

!!! warning
    1. It is possible to have a `TimeProfile` that is shorter or longer than the corresponding time structure.
       If the profile is shorter, then the last value is repeated.
       If the profile is longer, then the last values are omitted.
       `EnergyModelsBase` provides the user with a warning if either of the above cases occurs.

       It is hence strongly advised to use a `TimeProfile` with the same length.
    2. Not all variables allow for all types of `TimeProfile`.
       This is explained in the corresponding nodal page in the documentation.

### [FixedProfile](@id how_to-utilize_TS-profile-fixed)

[`FixedProfile`](@extref TimeStruct.FixedProfile) is the simplest profile.
It represents a constant value over the whole modelling horizon.
Its application is given by:

```julia
profile = FixedProfile(10)
```

This provides a value of `10` in all operational periods in all strategic periods.

### [OperationalProfile](@id how_to-utilize_TS-profile-operational)

[`OperationalProfile`](@extref TimeStruct.OperationalProfile) is used when there are operational variations, that is each operational period has different values.
Consider the following example time structure, corresponding to 5 strategic periods, each with a duration of 5 years, and 24 operational periods, each with a duration of 24 hours.

```julia
𝒯 = TwoLevel(5, 5, SimpleTimes(24, 1); op_per_strat=8760)
```

In this case, we can define an [`OperationalProfile`](@extref TimeStruct.OperationalProfile) as an array with length 24:

```julia
op_profile = OperationalProfile(collect(1:1.0:24))
```

The example has a progressively increasing value, from 1 in the first hour to 24 in the last hour.
In this example, `collect` is required to obtain the values as an array.

[`OperationalProfile`](@extref TimeStruct.OperationalProfile) is normally used for varying demand or profiles for renewable power generation.

### [ScenarioProfile](@id how_to-utilize_TS-profile-scenario)

[`ScenarioProfile`](@extref TimeStruct.ScenarioProfile)s can be included in the case of [`OperationalScenarios`](@extref TimeStruct.OperationalScenarios).
Each profile in the structure corresponds to the respective operational scenario.

Consider the following time structure,

```julia
week_1 = SimpleTimes(168, 1)
week_2 = SimpleTimes(168, 1)
prob = [0.9, 0.1]
oscs = OperationalScenarios([week_1, week_2], prob)

𝒯 = TwoLevel(5, 5, oscs; op_per_strat=8760)
```

in which two weeks with hourly resolution are operational scenarios.
The corresponding profiles then can look like the following:

```julia
profile_1_ = OperationalProfile(rand(168) .+ 5)
profile_2 = OperationalProfile(rand(168) .+ 10)
demand = ScenarioProfile([profile_1_, profile_2])
```
!!! warning
    It is possible to use [`ScenarioProfile`](@extref TimeStruct.ScenarioProfile) without [`OperationalScenarios`](@extref TimeStruct.OperationalScenarios).
    In this case, the first provided profile is used.

    `EnergyModelsBase` provides the user with a warning if this is the case.

### [RepresentativeProfile](@id how_to-utilize_TS-profile-representative)

[`RepresentativeProfile`](@extref TimeStruct.RepresentativeProfile)s can be included in the case of [`RepresentativePeriods`](@extref TimeStruct.RepresentativePeriods).
Each profile in the structure corresponds to the respective representative period.

Consider the following time structure,

```julia
winter_day = SimpleTimes(24, 1)
summer_day = SimpleTimes(24, 1)
rps = RepresentativePeriods(2, 8760, [0.5, 0.5], winter_day, summer_day)
𝒯 = TwoLevel(5, 5, rps; op_per_strat=8760)
```

in which two days with hourly resolution are scaled up 182.5 times each.
The corresponding profiles then can look like the following:

```julia
profile_winter = OperationalProfile(collect(range(1, stop=24, length=24)))
profile_summer = FixedProfile(0)
demand = RepresentativeProfile([profile_winter, profile_summer])
```

This implies that we can use both [`OperationalProfile`](@extref TimeStruct.OperationalProfile) and [`FixedProfile`](@extref TimeStruct.FixedProfile) combined.
The only requirement is that if one is using Integer input, then the other also has to use Integer input.

!!! warning
    It is possible to use [`RepresentativeProfile`](@extref TimeStruct.RepresentativeProfile) without [`RepresentativePeriods`](@extref TimeStruct.RepresentativePeriods).
    In this case, the first provided profile is used.

    `EnergyModelsBase` provides the user with a warning if this is the case.

### [StrategicProfile](@id how_to-utilize_TS-profile-strategic)

[`StrategicProfile`](@extref TimeStruct.StrategicProfile) is used when there are strategic variations.
Considering the same example time structure,

```julia
𝒯 = TwoLevel(5, 5, SimpleTimes(24, 1); op_per_strat=8760)
```

we can define a [`StrategicProfile`](@extref TimeStruct.StrategicProfile) as:

```julia
strat_profile = StrategicProfile([1, 2, 3, 4, 5])
```

In this case, we have variations between the strategic periods.
However, we use the same value in all operational periods within a strategic period, that is all operational periods in strategic period 1 would use a value of 1, while those in strategic period 2 use a value of 2, and so on.
This implementation is frequently used for changing capacities or efficiencies.

It is also possible to have both variations on the strategic and operational level.
A [`StrategicProfile`](@extref TimeStruct.StrategicProfile) then takes an Array of [`OperationalProfile`](@extref TimeStruct.OperationalProfile)s as input:

```julia
op_profile_1 = OperationalProfile(rand(24))
op_profile_2 = OperationalProfile(rand(24))
op_profile_3 = OperationalProfile(rand(24))
op_profile_4 = OperationalProfile(rand(24))
op_profile_5 = OperationalProfile(rand(24))
strat_profile = StrategicProfile([op_profile_1, op_profile_2, op_profile_3, op_profile_4, op_profile_5])
```

This approach is frequently used for demands where there are changes both on the operational level (*e.g.*, hour) and strategic level (*e.g.*, year).

It is similarly possible to include [`ScenarioProfile`](@extref TimeStruct.ScenarioProfile) and [`RepresentativeProfile`](@extref TimeStruct.RepresentativeProfile)s.

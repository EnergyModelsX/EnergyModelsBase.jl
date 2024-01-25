# [Utilize `TimeStruct.jl`](@id utilize_timestruct)

`EnergyModelsBase` uses for the description of time the package [`TimeStruct.jl`](https://sintefore.github.io/TimeStruct.jl/stable/).
[`TimeStruct.jl`](https://sintefore.github.io/TimeStruct.jl/stable/) offers a large variety of different options that can appear to be overwhelming, when first exposed to them.
Hence, it is important to highlight how it works and which parameters you would want to analyse.

## Structures for time description

`TimeStruct.jl` introduces individual structures that are used for describing time.
In the following introduction, the most important structures are explained.
There are other structures, but these will be added once `EnergyModelsbase.jl` supports their formulation.

### Operational periods

Operational periods correspond to periods in which no investments are allowed.
In general, you can imagine operational periods to be the individual hours you want to model, although it is not limited to hours.
In each operational period, we have an optimal dispatch problem given the constraints.
Operational periods are normally implemented using the type `SimpleTimes` which has the following structure:

```julia
op_duration = 1  # Each operational period has a duration of 1
op_number = 24   # There are in total 24 operational periods
operational_periods = SimpleTimes(op_number, op_duration)
```

In above's example, we assume that we have in total 24 operational periods which have the same duration each, _i.e._, a duration of 1.
The unit in itself is not important, but it can be either if you consider that a duration of 1 corresponds to one hour.
In this case, the operational periods would correspond to a full day.

!!! note

    All operational periods are continuous. This implies that one is not allowed to have jumps in the representative periods. This affects all "dynamic" constraints, that is, constraints where the current operational period is dependent on the previous operational period. In `EnergyModesBase.jl`, this is only the case for the level balance in `RefStorage`. Representative periods allow for jumps between operational periods, as outlined below.

Note that `TimeStruct.jl` does not require that each operational period has the same length.
Consider the following example:

```jldoctest test_label; setup = :(using TimeStruct)
op_duration = [4, 2, 1, 1, 2, 4, 2, 1, 1, 2, 4]
op_number = length(op_duration)
operational_periods = SimpleTimes(op_number, op_duration)

# output
SimpleTimes{Int64}(11, [4, 2, 1, 1, 2, 4, 2, 1, 1, 2, 4])
```

In this case, we model the day not with hourly resolution, but only have hourly resolution in the morning and afternoon.
The night has a reduced time resolution of 4 hours.
However, we still model a full 24 hours as can be seen by the command

```jldoctest test_label; setup = :(using TimeStruct)
duration(operational_periods)

# output
24
```

When having an `Array` as input to `SimpleTimes`, it is also not necessary to specify `op_number`.
Instead, one can also write

```jldoctest test_label; setup = :(using TimeStruct)
operational_periods = SimpleTimes(op_duration)

# output
SimpleTimes{Int64}(11, [4, 2, 1, 1, 2, 4, 2, 1, 1, 2, 4])
```

and a constructor will automatically deduce that there have to be 11 operational periods.

`SimpleTimes` is also the lowest `TimeStructure` that is present in `TimeStruct.jl`.
It is used in all subsequent structures.
When iterating over a `TimeStructure`, _e.g._, as `t ∈ operational_periods`, you obtain the single operational periods that are required for solving the optimal dispatch.

!!! warning

    Energy conversion, production, or emissions of a node as well as all flows are always defined for a duration of length 1 in operational periods. You have to be careful when considering the output from the model. The same holds for capacities provided in the input file.

### [Representative periods](@id ts_rp)

Representative periods are introduced through the structure `RepresentativePeriods`.
Representative periods correspond to a repetition of different periods.
This is a change from `SimpleTimes` in which a single period is scaled.

Consider the following example:

```julia
day = SimpleTimes(24, 1)
```

This example can represent a single day with hourly resolution.
In pracice, when including the `day` into a `TwoLevel`, it is scaled multiple times.
This can lead to an underestimation of storage requirements and makes it impossible to include seasonal storage.

Representative periods can be included through creating multiple instances of `SimpleTimes`.
The following example creates two days with hourly resolution, one winter day and one summer day.
These two days are the combined into a `RepresentativePeriod` with 2 periods.
These two periods sum up to a duration of 8760, that is a year.
Each representative period is scaled up `365/2=182.5` times.

```julia
winter_day = SimpleTimes(24, 1)
summer_day = SimpleTimes(24, 1)

periods = 2                 # Number of representative periods
total_duration = 8760       # Total duration
share = [0.5, 0.5]          # Share of the total duration of the representative periods

rps = RepresentativePeriods(periods, total_duration, share, winter_day, summer_day)
```

Representative periods only affect the system if storage is included.
In the case of storage, this scaling impacts the initial level of the storage in representative periods.
Otherwise, the application of `SimpleTimes` suffices.

### Strategic periods

Strategic periods are introduced through the structure `TwoLevel`.
They correspond to the periods in which changes in capacity, efficiency, or operational expenditures can occur.
The general structure is given by

```julia
day = SimpleTimes(24, 1)
strategic_duration = 5  # Each strategic period has a duration of 5
strategic_number = 5    # here are in total 5 strategic periods
T = TwoLevel(strategic_number, strategic_duration, day)
```

The example above corresponds to 5 strategic periods with a duration of 5 in each strategic period. Each strategic period includes 24 operational periods.
One can choose any reference duration for a strategic period and the corresponding duration of an operational period.
In above's example, there is no specified link between the duration of 1 of an operational period and a duration of 1 of a strategic period.
`TwoLevel` assumes in this situation that the link is 1, that is both the strategic periods and the operational periods have the same duration.

In general, it is easiest to use a duration of 1 of a strategic period to be equivalent to a single year while a duration of 1 of an operational period should correspond to 1 hour.
In this case, we have to specifiy `TwoLevel` slightly differently:

```julia
𝒯 = TwoLevel(strategic_number, strategic_duration, day; op_per_strat=8760)
```

Note, that we used in this example the optional keyword argument `op_per_strat` which links the duration 1 of an operational period to the duration 1 of a strategic period.
If we would like to have a duration of 1 in an operational period corresponding to an hour and a duration of 1 in a strategic period to a year, we need to use the value `op_per_strat = 365*24 = 8760`.

!!! warning

    It is important to be certain which value one should use for `op_per_strat`. When using the wrong value, one obtains wrong operational results that may affect the analysis.

Similar to the `SimpleTimes` structure, it is possible to also have strategic periods of varying durations.
In can be advantageous to, _e.g._, have a reduced duration in the initial investment periods, while having an increased duration in the latter.
This would allow to reflect the higher uncertainty associated with future decisions and improve computational tractability by reducing model instance size.

You can extract an iterator for the individual strategic periods by using the command:

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

The advantage of approach 1 is that you can also use the indices of the strategic period.
However, it may make the code look more complicated, when this is not required.
It does not have any implication on the model building speed and it is up to the user, which approach to choose.

!!! warning

    Fixed operational expenditures and emission limits provided to a model have to be provided for a duration of 1 in the strategic period.

### Summary

In the standard case, it is recommended to use **hour** as duration 1 of operational period and **year** as duration 1 of a strategic period.
This still allows to utilize a higher resolution, like _e.g._ 15 minutes or less through specifying a duration of 0.25 for these operational periods, but it simplifies the overall design.

```julia
day = SimpleTimes(24, 1)
strategic_duration = 5  # Each strategic period has a duration of 5
strategic_number = 5    # here are in total 5 strategic periods
𝒯 = TwoLevel(strategic_number, strategic_duration, day; op_per_strat=8760)
```

This is especially relevant for capacities and emission limits, as well as anlysing the values obtained from the model.

## Profiles

Profiles are used for providing parameters to the model.
There are in general three main profiles, that have to be considered:

1. `FixedProfile` represents using the same value in all periods,
2. `OperationalProfile` represents using the same profile in all strategic periods, although there can be variations in the individual strategic periods,
3. `RepresentativeProfile` represents a profile that differes in the individual representative periods, and
4. `StrategicProfile` represents using different values in the strategic periods.

### FixedProfile

`FixedProfile` is the simplest profile.
It represents a constant value over the whole modelling horizon.
Its application is given by:

```julia
profile = FixedProfile(10)
```

This would provide a value of `10` in all operational periods in all strategic periods.

### OperationalProfile

`OperationalProfile` is used when there are operational variations.
Consider the following example time structure, corresponding to 5 strategic periods, each with a duration of 5 years, and 24 operational periods, each with a duration of 24 hours.

```julia
𝒯 = TwoLevel(5, 5, SimpleTimes(24, 1); op_per_strat=8760)
```

In this case, we would need to define an `OperationalProfile` as an array with length 24:

```julia
op_profile = OperationalProfile(collect(1:1.0:24))
```

The example has a progressively increasing value going from 1 in the first hour to 24 in the last hour.
`collect` is in this example required to obtain the value as array.

`OperationalProfile` is normally used for varying demand or profiles for renewable power generation.

!!! warning

    It is possible to have an `OperationalProfile` that is shorter or longer than the profile in the time structure.
    If the profile is shorter, then the last value is repeated.
    If the profile is longer, then the last values are ommitted.
    `EnergyModelsBase` provides the user with a warning if one of above's cases are present

    It is hence strongly advise to use an `OperationalProfile` with the same length.

### RepresentativeProfile

`RepresentativeProfile`s can be included in the case of `RepresentativePeriods`.
Each profile in the structure corresponds to the respective representative period.

Consider the following time structure,

```julia
winter_day = SimpleTimes(24, 1)
summer_day = SimpleTimes(24, 1)
op = RepresentativePeriods(2, 8760, [0.5, 0.5], winter_day, summer_day)
𝒯 = TwoLevel(5, 5, ; op_per_strat=8760)
```

in which two days with hourly resolution are scaled up 182.5 times each.
The corresponding profiles then can look like the following:

```julia
profile_winter = OperationalProfile(collect(range(1, stop=24, length=24)))
profile_summer = FixedProfile(0)
demand = RepresentativeProfile([profile_winter, profile_summer])
```

This implies that we can use both `OperationalProfile` and `FixedProfile` combined.
The only requirement is that if one is using Integer input, then the other also has to use Integer input.

!!! warning

    It is possible to use `RepresentativeProfile` without `RepresentativePeriods`.
    In this case, the first provided profile is used.

    `EnergyModelsBase` provides the user with a warning if this is the case.

### StrategicProfile

`StrategicProfile` is used when there are strategic variations.
Considering the same example time structure,

```julia
𝒯 = TwoLevel(5, 5, SimpleTimes(24, 1); op_per_strat=8760)
```

we can define a `StrategicProfile` as:

```julia
strat_profile = StrategicProfile([1, 2, 3, 4, 5])
```

In this case, we have variations between the strategic periods, but use the same value in all operational periods within a strategic period, that is all operational periods in strategic period 1 would use a value of 1, while the once in strategic period 2 a value of 2, and so on.
This implementation is frequently used for changing capacities or efficiencies.

It is also possible to have both variations on the strategic and operational level.
A `StrategicProfile` then takes an Array of `OperationalProfile`s as input:

```julia
op_profile_1 = OperationalProfile(rand(24))
op_profile_2 = OperationalProfile(rand(24))
op_profile_3 = OperationalProfile(rand(24))
op_profile_4 = OperationalProfile(rand(24))
op_profile_5 = OperationalProfile(rand(24))
strat_profile = StrategicProfile([op_profile_1, op_profile_2, op_profile_3, op_profile_4, op_profile_5])
```

This approach is frequently used for demands where there are changes both on the operational level (_e.g._, hour) and strategic level (_e.g._, year).

It is similarly possible to include `RepresentativeProfile`s.

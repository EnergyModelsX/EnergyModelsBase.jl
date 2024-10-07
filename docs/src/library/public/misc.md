# [Miscellaneous types/functions/macros](@id lib-pub-misc_type)

## Index

```@index
Pages = ["misc.md"]
```

## Module

```@docs
EnergyModelsBase
```

## [`PreviousPeriods` and `CyclicPeriods`](@id lib-pub-misc_type-prev_cyclic)

`PreviousPeriods` is a type used to store information from the previous periods in an iteration loop through the application of the iterator [`withprev`](@extref TimeStruct.withprev) of `TimeStruct`.

`CyclicPeriods` is used for storing the current and the last period.
The periods can either be `AbstractStrategicPeriod` or `AbstractRepresentativePeriod`.
In the former case, it is however not fully used as the last strategic period is not relevant for the level balances.

Both composite types allow only `EMB.NothingPeriod` types as input to the individual fields.

```@docs
PreviousPeriods
CyclicPeriods
EMB.NothingPeriod
```

The individual fields can be accessed through the following functions:

```@docs
strat_per
rep_per
op_per
last_per
current_per
```

## [Macros for checking the input data](@id lib-pub-misc_type-macros)

The macro `@assert_or_log` is an extension to the `@assert` macro to allow either for asserting the input data directly, or logging the errors in the input data.

```@docs
@assert_or_log
```

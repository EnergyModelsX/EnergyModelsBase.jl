# Running the examples

You have to add the packages `TimeStruct`, `EnergyModelsBase`, `JuMP`, `HiGHS`, and `PrettyTables` to your current project in order to run the examples.
How to add packages is explained in the *[Quick start](https://energymodelsx.github.io/EnergyModelsBase.jl/dev/manual/quick-start/)* of the documentation

Once you have the respective pacakges installed in your project, you can run from the Julia REPL the following code:

```julia
# Starts the Julia REPL
julia> using EnergyModelsBase
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsBase), "examples")
# Include the code into the Julia REPL to run the first example
julia> include(joinpath(exdir, "sink_source.jl"))
```

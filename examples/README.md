# Running the examples

You have to add the package `EnergyModelsBase` to your current project in order to run the examples.
It is not necessary to add the other used packages, as the example is instantiating itself.
How to add packages is explained in the *[Quick start](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/manual/quick-start/)* of the documentation

You can run from the Julia REPL the following code:

```julia
# Starts the Julia REPL
julia> using EnergyModelsBase
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsBase), "examples")
# Include the code into the Julia REPL to run the first example
julia> include(joinpath(exdir, "sink_source.jl"))
```

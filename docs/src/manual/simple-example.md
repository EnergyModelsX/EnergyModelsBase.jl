# Examples

For the content of the individual examples, see the *[examples](https://github.com/EnergyModelsX/EnergyModelsBase.jl/tree/main/examples)* directory in the project repository.

## The package is installed with `] add`

From the Julia REPL, run

```julia
# Starts the Julia REPL
julia> using EnergyModelsBase
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsBase), "examples")
# Include the code into the Julia REPL to run the examples
julia> include(joinpath(exdir, "sink_source.jl"))
```

The second example can be run using

```julia
# Starts the Julia REPL
julia> using EnergyModelsBase
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsBase), "examples")
# Include the code into the Julia REPL to run the examples
julia> include(joinpath(exdir, "network.jl"))
```

## The code was downloaded with `git clone`

The examples can be run from the terminal with

```shell script
~/../energymodelsbase.jl/examples $ julia sink_source.jl
```

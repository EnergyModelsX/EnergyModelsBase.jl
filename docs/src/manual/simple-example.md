# Examples

For the content of the individual examples, see the [examples](https://gitlab.sintef.no/clean_export/energymodelsbase.jl/-/tree/main/examples) directory in the project repository.

## The package is installed with `] add`

First, add the [*Clean Export* Julia packages repository](https://gitlab.sintef.no/clean_export/registrycleanexport). Then run 
```
~/some/directory/ $ julia           # Starts the Julia REPL
julia> ]                            # Enter Pkg mode 
pkg> add EnergyModelsBase    # Install the package EnergyModelsBase to the current environment.
```
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

First, add the internal [*Clean Export* Julia package registry](https://gitlab.sintef.no/clean_export/registrycleanexport). The examples can then be run from the terminal with
```shell script
~/../energymodelsrenewableproducers.jl/examples $ julia sink_source.jl
```

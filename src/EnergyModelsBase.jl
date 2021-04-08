module EnergyModelsBase

using JuMP
using TimeStructures

include("datastructures.jl")
include("model.jl")
include("user_interface.jl")

# Export the genegal class
export EnergyModel

# Export the different node types
export Source
export Network
export Sink
export Storage

# Export the different link and ressource types
export Link
export RessourceEmit
export RessourceCarrier

end # module
module EnergyModelsBase

using JuMP
using TimeStructures

include("datastructures.jl")
include("model.jl")
include("checks.jl")
include("user_interface.jl")

# Export the general class
export EnergyModel

# Export the different node types
export Source
export Network
export Sink
export Storage

# Export the different link and resource types
export Link
export ResourceEmit
export ResourceCarrier

export @assert_or_log

end # module
module EnergyModelsBase

using JuMP
using TimeStructures

include("datastructures.jl")
include("model.jl")
include("user_interface.jl")

export EnergyModel  

end # module

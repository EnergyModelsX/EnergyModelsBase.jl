module EnergyModelsBase

using JuMP
using TimeStructures

include("datastructures.jl")
include("model.jl")
include("checks.jl")
include("user_interface.jl")

# Export the general classes
export EnergyModel, OperationalModel
export AbstractGlobalData, GlobalData
export Data, EmptyData

export Resource, ResourceCarrier, ResourceEmit

# Export the different node types
export Source, Network, Sink, Storage, Availability
export GenAvailability, RefGeneration, RefGeneration, RefSink, RefSource, RefStorage

export Linear, Link, Direct

export @assert_or_log
export create_model

end # module
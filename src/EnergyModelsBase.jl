"""
Main module for `EnergyModelsBase.jl`.
"""
module EnergyModelsBase

using JuMP
using TimeStructures

include("datastructures.jl")
include("utils.jl")
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
export GenAvailability, RefSource, RefNetwork, RefSink, RefStorage
export RefNetworkEmissions, RefStorageEmissions

export Linear, Link, Direct

export @assert_or_log
export create_model

end # module
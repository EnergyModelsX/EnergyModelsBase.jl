"""
Main module for `EnergyModelsBase.jl`.

This module provides the framework for building energy system models.
"""
module EnergyModelsBase

using JuMP
using TimeStruct

include("datastructures.jl")
include("utils.jl")
include("model.jl")
include("checks.jl")
include("constraint_functions.jl")

# Export the general classes
export EnergyModel, OperationalModel
export Data, EmptyData

export Resource, ResourceCarrier, ResourceEmit

# Export the different node types
export Source, Network, Sink, Storage, Availability
export GenAvailability, RefSource, RefNetwork, RefSink, RefStorage
export RefNetworkEmissions, RefStorageEmissions

export Linear, Link, Direct

export @assert_or_log
export create_model, run_model

end # module
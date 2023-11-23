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
export Source, NetworkNode, Sink, Storage, Availability
export GenAvailability, RefSource, RefNetworkNode, RefSink, RefStorage
export RefNetworkNodeEmissions, RefStorageEmissions

export Linear, Link, Direct

export @assert_or_log
export create_model, run_model
export variables_node, create_node
export constraints_capacity, constraints_capacity_installed
export constraints_flow_in, constraints_flow_out
export constraints_opex_fixed, constraints_opex_var

end # module

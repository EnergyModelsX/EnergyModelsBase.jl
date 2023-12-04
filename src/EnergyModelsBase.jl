"""
Main module for `EnergyModelsBase.jl`.

This module provides the framework for building energy system models.
"""
module EnergyModelsBase

using JuMP
using TimeStruct; const TS = TimeStruct

include("datastructures.jl")
include("utils.jl")
include("model.jl")
include("checks.jl")
include("constraint_functions.jl")
include("data_functions.jl")

# Legacy constructors for node types
include("legacy_constructor.jl")

# Export the general classes
export EnergyModel, OperationalModel

export Resource, ResourceCarrier, ResourceEmit

# Export the different node types
export Source, NetworkNode, Sink, Storage, Availability
export GenAvailability, RefSource, RefNetworkNode, RefSink, RefStorage

# Export the data types
export Data, EmptyData, EmissionsData, CaptureData
export CaptureProcessEnergyEmissions, CaptureProcessEmissions, CaptureEnergyEmissions
export EmissionsProcess, EmissionsEnergy

# Export the link types
export Linear, Link, Direct

# Legacy data types
export RefNetwork, RefNetworkEmissions, RefStorageEmissions

# Export commonly used functions for model generation
export @assert_or_log
export create_model, run_model
export variables_node, create_node
export constraints_capacity, constraints_capacity_installed
export constraints_flow_in, constraints_flow_out
export constraints_level
export constraints_opex_fixed, constraints_opex_var

export constraints_data

# Export commonly used functions for extracting fields in `Resource`
export co2_int

# Export commonly used functions for extracting fields in `EmissionsData`
export co2_capture, process_emissions

# Export commonly used functions for extracting fields in `Node`
export nodes_input, nodes_output
export capacity, input, output, opex_var, opex_fixed, surplus, deficit, storage_resource,
    node_data

# Export commonly used functions for extracting fields in `Link`
export formulation

# Export commonly used functions for extracting fields in `EnergyModel`
export emission_limit, co2_instance

end # module

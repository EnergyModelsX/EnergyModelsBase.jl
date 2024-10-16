"""
Main module for `EnergyModelsBase` a framework for building flexible energy system models.

It exports several types and associated functions for accessing fields.
In addition, all required functions for creaeting and running the model are exported.

You can find the exported types and functions below or on the pages \
*[Constraint functions](@ref man-con)* and \
*[Data functions](@ref man-data_fun)*.
"""
module EnergyModelsBase

using JuMP
using SparseVariables
using TimeStruct
const TS = TimeStruct

# Different introduced types
include(joinpath("structures", "resource.jl"))
include(joinpath("structures", "data.jl"))
include(joinpath("structures", "node.jl"))
include(joinpath("structures", "link.jl"))
include(joinpath("structures", "model.jl"))
include(joinpath("structures", "misc.jl"))

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

# Export some of the utility functions
export scale_op_sp

# Export the storage behaviour types
export Accumulating, AccumulatingEmissions
export Cyclic, CyclicRepresentative, CyclicStrategic

# Export the storage parameter types
export StorCapOpex, StorCap, StorCapOpexVar, StorCapOpexFixed, StorOpexVar

# Export the data types
export Data, EmptyData, EmissionsData, CaptureData
export CaptureProcessEnergyEmissions, CaptureProcessEmissions, CaptureEnergyEmissions
export EmissionsProcess, EmissionsEnergy

# Export the link types
export Linear, Link, Direct

# Export the miscellaneous types
export PreviousPeriods, CyclicPeriods

# Export of the types for investment models
export AbstractInvestmentModel, InvestmentModel
export InvestmentData, SingleInvData, StorageInvData
export InvData, InvDataStorage

# Export commonly used functions for model generation
export @assert_or_log
export create_model, run_model
export variables_node, create_node
export constraints_capacity, constraints_capacity_installed
export constraints_flow_in, constraints_flow_out
export constraints_level, constraints_level_aux
export constraints_opex_fixed, constraints_opex_var
export constraints_data

# Export functions used for level balancing modifications
export previous_level, previous_level_sp

# Export commonly used functions for extracting fields in `Resource`
export co2_int

# Export commonly used functions for extracting fields in `EmissionsData`
export co2_capture, process_emissions

# Export commonly used functions for extracting fields in `Node`
export nodes_input, nodes_output, nodes_emissions
export has_input, has_output, has_emissions
export capacity,
    inputs,
    outputs,
    opex_var,
    opex_fixed,
    surplus_penalty,
    deficit_penalty,
    storage_resource,
    node_data

# Export commonly used functions for extracting fields in `AbstractStorageParameters`
export has_charge, has_discharge
export charge, level, discharge

# Export commonly used functions for extracting fields in `Link`
export formulation

# Export commonly used functions for extracting fields in `EnergyModel`
export emission_limit, emission_price, co2_instance, discount_rate

# Export commonly used functions for extracting fields in `PreviousPeriods` and `CyclicPeriods`
export strat_per, rep_per, op_per, last_per, current_per

end # module

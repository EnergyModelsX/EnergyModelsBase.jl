using Pkg
# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMB_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
# Install the dependencies.
Pkg.instantiate()

# Import the required packages
using EnergyModelsBase
using JuMP
using HiGHS
using PrettyTables
using TimeStruct

"""
    generate_example_data_ss()

Generate the data for an example consisting of an electricity source and sink. It shows how
the source adjusts to the demand.
"""
function generate_example_data_ss()
    @info "Generate case data - Simple sink-source example"

    # Define the different resources and their emission intensity in tCO2/MWh
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods, which
    # can also be extracted using the function `duration` of a `SimpleTimes` structure.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = op_duration * op_number

    # Creation of the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO₂ in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        CO2,                            # CO₂ instance
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    nodes = [
        RefSource(
            "electricity source",       # Node id
            FixedProfile(1e12),         # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/8h
            Dict(Power => 1),           # Output from the Node, in this case, Power
        ),
        RefSink(
            "electricity demand",       # Node id
            OperationalProfile([20, 30, 40, 30]), # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(Power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
        Direct("source-demand", nodes[1], nodes[2], Linear()),
    ]

    # WIP data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )
    return case, model
end

# Generate the case and model data and run the model
case, model = generate_example_data_ss()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
source, sink = case[:nodes]
@info "Capacity usage of the power source"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_use][source, :];
        header = [:t, :Value],
    ),
)

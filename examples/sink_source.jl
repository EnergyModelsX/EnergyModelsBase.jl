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
    generate_example_ss()

Generate the data for an example consisting of an electricity source and sink. It shows how
the source adjusts to the demand.
"""
function generate_example_ss()
    @info "Generate case data - Simple sink-source example"

    # Define the different resources and their emission intensity in t CO₂/MWh
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("CO₂", 1.0)
    products = [power, co2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2 (hours)
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
        Dict(co2 => FixedProfile(10)),  # Emission cap for CO₂ in t/8h
        Dict(co2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        co2,                            # CO₂ instance
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    nodes = [
        RefSource(
            "electricity source",       # Node id
            FixedProfile(50),           # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/MW/8h
            Dict(power => 1),           # Output from the Node, in this case, power
        ),
        RefSink(
            "electricity demand",       # Node id
            OperationalProfile([20, 30, 40, 30]), # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect the two nodes
    # NOTE: This hard coding based on indexing is error prone. It is in general advised to
    #       use a mapping dictionary to avoid any problems when introducing new technology
    #       nodes.
    links = [
        Direct("source-demand", nodes[1], nodes[2], Linear()),
    ]

    # Input data structure
    # It is also explained on
    # https://energymodelsx.github.io/EnergyModelsBase.jl/stable/library/public/case_element/
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])
    return case, model
end

# Generate the case and model data and run the model
case, model = generate_example_ss()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

"""
    process_ss_results(m, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_ss_results(m, case)
    # Extract the nodes from the case data
    source, sink = get_nodes(case)

    # Node variables
    source_use = sort(                      # Usage of the source node
            JuMP.Containers.rowtable(
                value,
                m[:cap_use][source, :];
                header = [:t, :val],
        ),
        by = x -> x.t,
    )
    sink_use = sort(                        # Usage of the source node
            JuMP.Containers.rowtable(
                value,
                m[:cap_use][sink, :];
                header = [:t, :val],
        ),
        by = x -> x.t,
    )

    # Set up the individual named tuples as a single named tuple
    table = [(
            t = repr(con_1.t),
            source_use = round(con_1.val; digits=1),
            sink_use = round(con_2.val; digits=1),
        ) for (con_1, con_2, ) ∈
        zip(source_use, sink_use, )
    ]
    return table
end

# Display some results
table = process_ss_results(m, case)

@info(
    "Individual operational results from the source-sink example:\n" *
    "The capacity usage of the source and the sink node are the same as the penalty for not\n" *
    "delivering power is significantly higher than the variable OPEX in the source node."
)
pretty_table(table)

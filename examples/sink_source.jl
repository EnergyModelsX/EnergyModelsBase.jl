using Pkg
# Activate the test-environment, where PrettyTables and HiGHS are added as dependencies.
Pkg.activate(joinpath(@__DIR__, "../test"))
# Install the dependencies.
Pkg.instantiate()
# Add the package EnergyModelsBase to the environment.
Pkg.develop(path=joinpath(@__DIR__, ".."))

using EnergyModelsBase
using JuMP
using HiGHS
using Pkg
using PrettyTables
using TimeStruct


function generate_data()
    @info "Generate case data"

    # Define the different resources and their emission intensity in tCO2/MWh
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [Power, CO2]

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    nodes = [
        RefSource(
            1,                          # Node id
            FixedProfile(1e12),         # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/8h
            Dict(Power => 1),           # Output from the Node, in this gase, Power
            [],                         # Potential additional data
        ),
        RefSink(
            2,                          # Node id
            OperationalProfile([20 30 40 30]), # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(Power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
        Direct(12, nodes[1], nodes[2], Linear())
    ]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods, which
    # can also be extracted using the function `duration` which corresponds to the total
    # duration of the operational periods in a `SimpleTimes` structure
    op_per_strat = duration(operational_periods)

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )

    # WIP data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )
    return case, model
end


case, model = generate_data()
m = run_model(case, model, HiGHS.Optimizer)


# Inspect some of the results
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:flow_in];
        header=[:Node, :t, :Product, :Value]
    ),
)


source, sink = case[:nodes]
power = case[:products][1]

# Flow between the nodes
for t ∈ case[:T]
    @show t
    @show value.(m[:flow_out][source, t, power])
    @show value.(m[:flow_in][sink, t, power])
end

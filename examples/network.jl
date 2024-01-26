using Pkg
Pkg.activate(joinpath(@__DIR__, "../test"))
Pkg.instantiate()
Pkg.develop(path=joinpath(@__DIR__, ".."))

using EnergyModelsBase
using JuMP
using HiGHS
using Pkg
using PrettyTables
using TimeStruct


function generate_data()
    @info "Generate case data"

    # Define the different resources
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [NG, Coal, Power, CO2]

    # Creation of the emission data for the individual nodes.
    capture_data = CaptureEnergyEmissions(0.9)
    emission_data = EmissionsEnergy()

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO2 storage.
    nodes = [
        GenAvailability(1, products),
        RefSource(2, FixedProfile(1e12), FixedProfile(30),
            FixedProfile(0), Dict(NG => 1),
            []),
        RefSource(3, FixedProfile(1e12), FixedProfile(9),
            FixedProfile(0), Dict(Coal => 1),
            []),
        RefNetworkNode(4, FixedProfile(25), FixedProfile(5.5),
            FixedProfile(0), Dict(NG => 2),
            Dict(Power => 1, CO2 => 1),
            [capture_data]),
        RefNetworkNode(5, FixedProfile(25), FixedProfile(6),
            FixedProfile(0), Dict(Coal => 2.5),
            Dict(Power => 1),
            [emission_data]),
        RefStorage(6, FixedProfile(60), FixedProfile(600), FixedProfile(9.1),
            FixedProfile(0), CO2, Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),
            Array{Data}([])),
        RefSink(7, OperationalProfile([20 30 40 30]),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            Dict(Power => 1),
            []),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
        Direct(14, nodes[1], nodes[4], Linear())
        Direct(15, nodes[1], nodes[5], Linear())
        Direct(16, nodes[1], nodes[6], Linear())
        Direct(17, nodes[1], nodes[7], Linear())
        Direct(21, nodes[2], nodes[1], Linear())
        Direct(31, nodes[3], nodes[1], Linear())
        Direct(41, nodes[4], nodes[1], Linear())
        Direct(51, nodes[5], nodes[1], Linear())
        Direct(61, nodes[6], nodes[1], Linear())
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
        Dict(
            CO2 => StrategicProfile([160, 140, 120, 100]),
            NG => FixedProfile(1e6)
        ),
        Dict(
            CO2 => FixedProfile(0),
            NG => FixedProfile(0),
        ),
        CO2,
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


pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:flow_in];
        header=[:Node, :t, :Product, :Value]
    ),
)

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
using PrettyTables
using TimeStruct


function generate_data()
    @info "Generate case data"

    # Define the different resources and their emission intensity in tCO2/MWh
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [NG, Coal, Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods, which
    # can also be extracted using the function `duration` of a `SimpleTimes` structure.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = duration(operational_periods)

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(   # Emission cap for CO₂ in t/8h and for NG in MWh/8h
            CO2 => StrategicProfile([160, 140, 120, 100]),
            NG => FixedProfile(1e6)
        ),
        Dict(   # Emission price for CO₂ in EUR/t and for NG in EUR/MWh
            CO2 => FixedProfile(0),
            NG => FixedProfile(0),
        ),
        CO2,    # CO2 instance
    )

    # Creation of the emission data for the individual nodes.
    capture_data = CaptureEnergyEmissions(0.9)
    emission_data = EmissionsEnergy()

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO₂ storage.
    nodes = [
        GenAvailability(1, products),
        RefSource(
            2,                          # Node id
            FixedProfile(1e12),         # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/8h
            Dict(NG => 1),              # Output from the Node, in this gase, NG
        ),
        RefSource(
            3,                          # Node id
            FixedProfile(1e12),         # Capacity in MW
            FixedProfile(9),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/8h
            Dict(Coal => 1),            # Output from the Node, in this gase, coal
        ),
        RefNetworkNode(
            4,                          # Node id
            FixedProfile(25),           # Capacity in MW
            FixedProfile(5.5),          # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/8h
            Dict(NG => 2),              # Input to the node with input ratio
            Dict(Power => 1, CO2 => 1), # Output from the node with output ratio
            # Line above: CO2 is required as output for variable definition, but the
            # value does not matter
            [capture_data],             # Additonal data for emissions and CO₂ capture
        ),
        RefNetworkNode(
            5,                          # Node id
            FixedProfile(25),           # Capacity in MW
            FixedProfile(6),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/8h
            Dict(Coal => 2.5),          # Input to the node with input ratio
            Dict(Power => 1),           # Output from the node with output ratio
            [emission_data],            # Additonal data for emissions
        ),
        RefStorage(
            6,                          # Node id
            FixedProfile(60),           # Rate capacity in t/h
            FixedProfile(600),          # Storage capacity in t
            FixedProfile(9.1),          # Storage variable OPEX for the rate in EUR/t
            FixedProfile(0),            # Storage fixed OPEX for the rate in EUR/(t/h 8h)
            CO2,                        # Stored resource
            Dict(CO2 => 1, Power => 0.02), # Input resource with input ratio
            # Line above: This implies that storing CO₂ requires Power
            Dict(CO2 => 1),             # Output from the node with output ratio
            # In practice, for CO₂ storage, this is never used.
        ),
        RefSink(
            7,                          # Node id
            OperationalProfile([20 30 40 30]), # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(Power => 1),           # Energy demand and corresponding ratio
        ),
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

    # WIP data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )
    return case, model
end

# Create the case and model data and run the model
case, model = generate_data()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
@info "Capacity usage of the coal power plant"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_use][case[:nodes][5], :];
        header=[:t, :Value]
    ),
)
@info "Capacity usage of the nautral gas + CCS power plant"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_use][case[:nodes][4], :];
        header=[:t, :Value]
    ),
)

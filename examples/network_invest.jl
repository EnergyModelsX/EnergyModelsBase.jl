using Pkg
# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMB_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
# Install the dependencies.
Pkg.instantiate()

# Import the required packages
using EnergyModelsBase
using EnergyModelsInvestments
using JuMP
using HiGHS
using PrettyTables
using TimeStruct

"""
    generate_example_network_investment()

Generate the data for an example consisting of a simple electricity network.
The more stringent CO₂ emission in latter investment periods force the investment into both
the natural gas power plant with CCS and the CO₂ storage node.
"""
function generate_example_network_investment()
    @info "Generate case data - Simple network example with investments"

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

    # Each operational period should correspond to a duration of 2 h while a duration if 1
    # of a strategic period should correspond to a year.
    # This implies, that a strategic period is 8760 times longer than an operational period,
    # resulting in the values below as "/year".
    op_per_strat = 8760

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, operational_periods; op_per_strat)
    model = InvestmentModel(
        Dict(   # Emission cap for CO₂ in t/year and for NG in MWh/year
            CO2 => StrategicProfile([170, 150, 130, 110]) * 1000,
            NG => FixedProfile(1e6),
        ),
        Dict(   # Emission price for CO₂ in EUR/t and for NG in EUR/MWh

            CO2 => FixedProfile(0),
            NG => FixedProfile(0),
        ),
        CO2,    # CO2 instance
        0.07,   # Discount rate in absolute value
    )

    # Creation of the emission data for the individual nodes.
    capture_data = CaptureEnergyEmissions(0.9)
    emission_data = EmissionsEnergy()

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO₂ storage.
    nodes = [
        GenAvailability("Availability", products),
        RefSource(
            "NG source",                # Node id
            FixedProfile(100),          # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(NG => 1),              # Output from the Node, in this case, NG
        ),
        RefSource(
            "coal source",              # Node id
            FixedProfile(100),          # Capacity in MW
            FixedProfile(9),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(Coal => 1),            # Output from the Node, in this case, coal
        ),
        RefNetworkNode(
            "NG+CCS power plant",       # Node id
            FixedProfile(0),            # Capacity in MW
            FixedProfile(5.5),          # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(NG => 2),              # Input to the node with input ratio
            Dict(Power => 1, CO2 => 0), # Output from the node with output ratio
            # Line above: CO2 is required as output for variable definition, but the
            # value does not matter
            [
                capture_data,           # Additonal data for emissions and CO₂ capture
                SingleInvData(
                    FixedProfile(600 * 1e3),  # Capex in EUR/MW
                    FixedProfile(40),       # Max installed capacity [MW]
                    SemiContinuousInvestment(FixedProfile(5), FixedProfile(40)),
                    # Line above: Investment mode with the following arguments:
                    # 1. argument: min added capactity per sp [MW]
                    # 2. argument: max added capactity per sp [MW]
                ),
            ],
        ),
        RefNetworkNode(
            "coal power plant",         # Node id
            FixedProfile(40),           # Capacity in MW
            FixedProfile(6),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(Coal => 2.5),          # Input to the node with input ratio
            Dict(Power => 1),           # Output from the node with output ratio
            [emission_data],            # Additonal data for emissions
        ),
        RefStorage{AccumulatingEmissions}(
            "CO2 storage",              # Node id
            StorCapOpex(
                FixedProfile(0),       # Charge capacity in t/h
                FixedProfile(9.1),      # Storage variable OPEX for the charging in EUR/t
                FixedProfile(0)         # Storage fixed OPEX for the charging in EUR/(t/h year)
            ),
            StorCap(FixedProfile(1e8)), # Storage capacity in t
            CO2,                        # Stored resource
            Dict(CO2 => 1, Power => 0.02), # Input resource with input ratio
            # Line above: This implies that storing CO₂ requires Power
            Dict(CO2 => 1),             # Output from the node with output ratio
            # In practice, for CO₂ storage, this is never used.
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(200 * 1e3),  # CAPEX [EUR/(t/h)]
                        FixedProfile(60),       # Max installed capacity [EUR/(t/h)]
                        ContinuousInvestment(FixedProfile(0), FixedProfile(5)),
                        # Line above: Investment mode with the following arguments:
                        # 1. argument: min added capactity per sp [t/h]
                        # 2. argument: max added capactity per sp [t/h]
                        UnlimitedLife(),        # Lifetime mode
                    ),
                ),
            ],
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
        Direct("Av-NG_pp", nodes[1], nodes[4], Linear())
        Direct("Av-coal_pp", nodes[1], nodes[5], Linear())
        Direct("Av-CO2_stor", nodes[1], nodes[6], Linear())
        Direct("Av-demand", nodes[1], nodes[7], Linear())
        Direct("NG_src-av", nodes[2], nodes[1], Linear())
        Direct("Coal_src-av", nodes[3], nodes[1], Linear())
        Direct("NG_pp-av", nodes[4], nodes[1], Linear())
        Direct("Coal_pp-av", nodes[5], nodes[1], Linear())
        Direct("CO2_stor-av", nodes[6], nodes[1], Linear())
    ]

    # Input data structure
    case = Case(T, products, [nodes, links], [[f_nodes, f_links]])
    return case, model
end

# Generate the case and model data and run the model
case, model = generate_example_network_investment()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
ng_ccs_pp, CO2_stor, = f_nodes(case)[[4, 6]]
@info "Invested capacity for the natural gas plant in the beginning of the \
individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_add][ng_ccs_pp, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)
@info "Invested capacity for the CO2 storage in the beginning of the
individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:stor_charge_add][CO2_stor, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)

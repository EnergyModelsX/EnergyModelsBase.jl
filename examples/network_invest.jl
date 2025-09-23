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

    # Define the different resources and their emission intensity in t CO₂/MWh
    ng = ResourceEmit("ng", 0.2)
    coal = ResourceCarrier("coal", 0.35)
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("CO₂", 1.0)
    products = [ng, coal, power, co2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2 (hours)
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # Each operational period should correspond to a duration of 2 h while a duration of 1
    # of a strategic period should correspond to a year.
    # This implies, that a strategic period is 8760 times longer than an operational period,
    # resulting in the values below as "/year".
    op_per_strat = 8760

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, operational_periods; op_per_strat)
    model = InvestmentModel(
        Dict(   # Emission cap for CO₂ in t/year and for NG in MWh/year
            co2 => StrategicProfile([170, 150, 130, 110]) * 1000,
            ng => FixedProfile(1e6),
        ),
        Dict(   # Emission price for CO₂ in EUR/t and for NG in EUR/MWh

            co2 => FixedProfile(0),
            ng => FixedProfile(0),
        ),
        co2,    # CO₂ instance
        0.07,   # Discount rate in absolute value
    )

    # Creation of the emission data for the individual nodes.
    emission_data = EmissionsEnergy()
    # Line above: `EmissionsEnergy` implies that the emissions data corresponds to
    # emissions through fuel usage as calculated by the CO₂ intensity and efficiency.
    capture_data = CaptureEnergyEmissions(0.9)
    # Line above: `CaptureEnergyEmissions` implies that the emissions data corresponds
    # to emissions through fuel usage as calculated by the CO₂ intensity and efficiency.
    # 90 % of the CO₂ emissions are captured as given by the value 0.9.

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO₂ storage.
    nodes = [
        GenAvailability("Availability", products),
        RefSource(
            "NG source",                # Node id
            FixedProfile(100),          # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(ng => 1),              # Output from the Node, in this case, ng
        ),
        RefSource(
            "coal source",              # Node id
            FixedProfile(100),          # Capacity in MW
            FixedProfile(9),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(coal => 1),            # Output from the Node, in this case, coal
        ),
        RefNetworkNode(
            "NG+CCS power plant",       # Node id
            FixedProfile(0),            # Capacity in MW
            FixedProfile(5.5),          # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(ng => 2),              # Input to the node with input ratio
            Dict(power => 1, co2 => 0), # Output from the node with output ratio
            # Line above: `co2` is required as output for variable definition, but the
            # value does not matter as it is not utilized in the model.
            [
                capture_data,           # Additional data for emissions and CO₂ capture
                SingleInvData(
                    FixedProfile(600 * 1e3),    # Capex in EUR/MW
                    FixedProfile(40),           # Maximum installed capacity [MW]
                    SemiContinuousInvestment(FixedProfile(5), FixedProfile(40)),
                    # Line above: Investment mode with the following arguments:
                    # 1. argument: minimum added capactity  per sp [MW]
                    # 2. argument: maximum added capactity per sp [MW]
                    # `SemiContinuousInvestment` implies that one either invests at least in
                    # the minimum added capacity, or not at all.
                ),
            ],
        ),
        RefNetworkNode(
            "coal power plant",         # Node id
            FixedProfile(40),           # Capacity in MW
            FixedProfile(6),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(coal => 2.5),          # Input to the node with input ratio
            Dict(power => 1),           # Output from the node with output ratio
            [emission_data],            # Additonal data for emissions
        ),
        RefStorage{AccumulatingEmissions}(
            "CO₂ storage",              # Node id
            StorCapOpex(
                FixedProfile(0),       # Charge capacity in t/h
                FixedProfile(9.1),      # Storage variable OPEX for the charging in EUR/t
                FixedProfile(0)         # Storage fixed OPEX for the charging in EUR/(t/h year)
            ),
            StorCap(FixedProfile(1e8)), # Storage capacity in t
            co2,                        # Stored resource
            Dict(co2 => 1, power => 0.02), # Input resource with input ratio
            # Line above: This implies that storing CO₂ requires power
            Dict(co2 => 1),             # Output from the node with output ratio
            # Line above: In the case of `AccumulatingEmissions`, you must provide the
            # stored resource as one of the keys. Its value does however not matter as the
            # outlet flow value is fixed to 0.
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(200 * 1e3),    # CAPEX [EUR/(t/h)]
                        FixedProfile(60),           # Maximum installed capacity [EUR/(t/h)]
                        ContinuousInvestment(FixedProfile(0), FixedProfile(5)),
                        # Line above: Investment mode with the following arguments:
                        # 1. argument: min added capactity per sp [t/h]
                        # 2. argument: max added capactity per sp [t/h]
                        # `ContinuousInvestment` implies you can invest in a capacity between
                        # 0 and 5 t/h in each strategic period
                        UnlimitedLife(),        # Lifetime mode corresponding to no retirement of capacity
                    ),
                ),
            ],
        ),
        RefSink(
            "electricity demand",       # Node id
            OperationalProfile([20, 30, 40, 30]), # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    # NOTE: This hard coding based on indexing is error prone. It is in general advised to
    #       use a mapping dictionary to avoid any problems when introducing new technology
    #       nodes.
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
    # It is also explained on
    # https://energymodelsx.github.io/EnergyModelsBase.jl/stable/library/public/case_element/
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])
    return case, model
end

# Generate the case and model data and run the model
case, model = generate_example_network_investment()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
ng_ccs_pp, CO2_stor, = get_nodes(case)[[4, 6]]
@info "Invested capacity for the natural gas plant in the beginning of the \
individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_add][ng_ccs_pp, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)
@info "Invested capacity for the CO₂ storage in the beginning of the
individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:stor_charge_add][CO2_stor, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)

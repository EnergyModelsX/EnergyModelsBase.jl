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
    generate_example_ss_investment(lifemode = RollingLife; discount_rate = 0.05)

Generate the data for an example consisting of an electricity source and sink.
The electricity source has initially no capacity. Hence, investments are required.
"""
function generate_example_ss_investment(lifemode = RollingLife; discount_rate = 0.05)
    @info "Generate case data - Simple sink-source example"

    # Define the different resources and their emission intensity in tCO2/MWh
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # Each operational period should correspond to a duration of 2 h while a duration if 1
    # of a strategic period should correspond to a year.
    # This implies, that a strategic period is 8760 times longer than an operational period,
    # resulting in the values below as "/year".
    op_per_strat = 8760

    sp_duration = 5 # The duration of a investment period is given as 5 years

    # Creation of the time structure and global data
    T = TwoLevel(4, sp_duration, operational_periods; op_per_strat)

    # Create the global data
    model = InvestmentModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO₂ in t/year
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        CO2,                            # CO₂ instance
        discount_rate,                  # Discount rate in absolute value
    )


    # The lifetime of the technology is 15 years, requiring reinvestment in the
    # 5th investment period
    lifetime = FixedProfile(15)

    # Create the investment data for the source node
    investment_data_source = SingleInvData(
        FixedProfile(300 * 1e3),  # capex [€/MW]
        FixedProfile(50),       # max installed capacity [MW]
        ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
        # Line above: Investment mode with the following arguments:
        # 1. argument: min added capactity per sp [MW]
        # 2. argument: max added capactity per sp [MW]
        lifemode(lifetime),     # Lifetime mode
    )


    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    nodes = [
        RefSource(
            "electricity source",       # Node id
            FixedProfile(0),            # Capacity in MW
            FixedProfile(10),           # Variable OPEX in EUR/MW
            FixedProfile(5),            # Fixed OPEX in EUR/MW/year
            Dict(Power => 1),           # Output from the Node, in this case, Power
            [investment_data_source],   # Additional data used for adding the investment data
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

    # Input data structure
    case = Case(T, products, [nodes, links], [[f_nodes, f_links]])
    return case, model
end

# Generate the case and model data and run the model
case, model = generate_example_ss_investment()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
source, sink = f_nodes(case)
@info "Invested capacity for the source in the beginning of the individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_add][source, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)
@info "Retired capacity of the source at the end of the individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_rem][source, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)

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
    generate_example_ss_investment()

Generate the data for an example consisting of an electricity source and sink.
The electricity source has initially no capacity. Hence, investments are required.
"""
function generate_example_ss_investment()
    @info "Generate case data - Simple sink-source example"

    # Define the different resources and their emission intensity in t CO₂/MWh
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("CO₂", 1.0)
    products = [power, co2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2c
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # Each operational period should correspond to a duration of 2 h while a duration of 1
    # of a strategic period should correspond to a year.
    # This implies, that a strategic period is 8760 times longer than an operational period,
    # resulting in the values below as "/year".
    op_per_strat = 8760

    sp_duration = 5 # The duration of a investment period is given as 5 years

    # Creation of the time structure and global data
    T = TwoLevel(4, sp_duration, operational_periods; op_per_strat)

    # Create the global data
    model = InvestmentModel(
        Dict(co2 => FixedProfile(10)),  # Emission cap for CO₂ in t/year
        Dict(co2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        co2,                            # CO₂ instance
        0.05,                           # Discount rate in absolute value
    )

    # The lifetime of the technology is 15 years, requiring reinvestment in the
    # 5th investment period
    lifetime = FixedProfile(15)

    # Create the investment data for the source node
    investment_data_source = SingleInvData(
        FixedProfile(300 * 1e3),    # CAPEX [€/MW]
        FixedProfile(50),           # Maximum installed capacity [MW]
        ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
        # Line above: Investment mode with the following arguments:
        # 1. argument: minimum added capactity per sp [MW]
        # 2. argument: maximum added capactity per sp [MW]
        # `ContinuousInvestment` implies you can invest in a capacity between 0 and 30 MW in
        # each strategic period
        RollingLife(lifetime),     # Lifetime mode
        # Line above: As default we are using `RollingLife` with a lifetime of 15 years
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    nodes = [
        RefSource(
            "electricity source",       # Node id
            FixedProfile(0),            # Capacity in MW
            FixedProfile(10),           # Variable OPEX in EUR/MW
            FixedProfile(5),            # Fixed OPEX in EUR/MW/year
            Dict(power => 1),           # Output from the Node, in this case, power
            [investment_data_source],   # Additional data used for adding the investment data
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
case, model = generate_example_ss_investment()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

"""
    process_ss_investment_results(m, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_ss_investment_results(m, case)
    # Extract the nodes and time structure from the case data
    source, sink = get_nodes(case)
    𝒯ⁱⁿᵛ = strategic_periods(get_time_struct(case))

    # Node variables
    source_current = sort(                      # Capacity of the source node
            JuMP.Containers.rowtable(
                value,
                m[:cap_current][source, :];
                header = [:t_inv, :val],
        ),
        by = x -> x.t_inv,
    )
    source_add = sort(                          # Investments in the source node
            JuMP.Containers.rowtable(
                value,
                m[:cap_add][source, :];
                header = [:t_inv, :val],
        ),
        by = x -> x.t_inv,
    )
    source_remove = sort(                       # Retirement from the source node
            JuMP.Containers.rowtable(
                value,
                m[:cap_rem][source, :];
                header = [:t_inv, :val],
        ),
        by = x -> x.t_inv,
    )

    sink_deficit = sort(                        # Sink deficit in each strategic period
            [(
                t_inv=t_inv,
                val=sum(value.(m[:sink_deficit][sink, t])*scale_op_sp(t_inv, t) for t ∈ t_inv)
            ) for t_inv ∈ 𝒯ⁱⁿᵛ],
        by = x -> x.t_inv,
    )

    # Set up the individual named tuples as a single named tuple
    table = [(
            t_inv = repr(con_1.t_inv),
            capacity = round(con_1.val; digits=1),
            capacity_addition = round(con_2.val; digits=1),
            capacity_removal = round(con_3.val; digits=1),
            deficit = round(con_4.val; digits=1),
        ) for (con_1, con_2, con_3, con_4) ∈
        zip(source_current, source_add, source_remove, sink_deficit)
    ]
    return table
end

# Display some results
table = process_ss_investment_results(m, case)

@info(
    "Individual strategic results from the source-sink example:\n" *
    "The source node receives investments in the first strategic period. However, due to the\n" *
    "maximum capacity additions, we still see a deficit. It is hence required to invest also\n" *
    "in the second strategic period. The capacities are removed at the end of the lifetime\n" *
    "given by 3 strategic periods (3*5 years = 15 years). As a consequence, reinvestments are\n" *
    "neccesary in strategic period 4. Note that the removal is happening at the end of a\n" *
    "strategic period."
)
pretty_table(table)

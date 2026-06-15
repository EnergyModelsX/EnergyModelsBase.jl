function generate_data(; 𝒯 = TwoLevel(4, 2, SimpleTimes(4, 2), op_per_strat = 8.0))

    # Define the different resources
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    𝒫 = [NG, Coal, Power, CO2]

    # Creation of the emission data for the individual nodes.
    capture_data = CaptureEnergyEmissions(0.9)
    emission_data = EmissionsEnergy()

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO2 storage.
    𝒩 = [
        GenAvailability(1, 𝒫),
        RefSource(2, FixedProfile(100), FixedProfile(30), FixedProfile(0), Dict(NG => 1)),
        RefSource(3, FixedProfile(100), FixedProfile(9), FixedProfile(0), Dict(Coal => 1)),
        RefNetworkNode(
            4,
            FixedProfile(25),
            FixedProfile(5.5),
            FixedProfile(5),
            Dict(NG => 2),
            Dict(Power => 1, CO2 => 1),
            [capture_data],
        ),
        RefNetworkNode(
            5,
            FixedProfile(25),
            FixedProfile(6),
            FixedProfile(10),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [emission_data],
        ),
        RefStorage{AccumulatingEmissions}(
            6,
            StorCapOpex(FixedProfile(60), FixedProfile(9.1), FixedProfile(0)),
            StorCap(FixedProfile(600)),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
        ),
        RefSink(
            7,
            OperationalProfile([20, 30, 40, 30]),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            Dict(Power => 1),
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    ℒ = [
        Direct(14, 𝒩[1], 𝒩[4], Linear())
        Direct(15, 𝒩[1], 𝒩[5], Linear())
        Direct(16, 𝒩[1], 𝒩[6], Linear())
        Direct(17, 𝒩[1], 𝒩[7], Linear())
        Direct(21, 𝒩[2], 𝒩[1], Linear())
        Direct(31, 𝒩[3], 𝒩[1], Linear())
        Direct(41, 𝒩[4], 𝒩[1], Linear())
        Direct(51, 𝒩[5], 𝒩[1], Linear())
        Direct(61, 𝒩[6], 𝒩[1], Linear())
    ]

    # Creation of the modeltype
    modeltype = OperationalModel(
        Dict(CO2 => StrategicProfile([160, 140, 120, 100]), NG => FixedProfile(1e6)),
        Dict(CO2 => FixedProfile(10)),
        CO2,
    )

    # Input data structure
    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]])
    return case, modeltype
end

@testset "General tests" begin
    case, modeltype = generate_data()
    m = run_model(case, modeltype, HiGHS.Optimizer)

    # Retrieve data from the case structure
    𝒫 = get_products(case)
    NG = 𝒫[1]
    CO2 = 𝒫[4]

    𝒯 = get_time_struct(case)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    𝒩 = get_nodes(case)
    𝒩ᵒᵖᵉˣ = filter(EMB.has_opex, 𝒩)
    𝒩ᵉᵐ = nodes_emissions(𝒩)
    avail = 𝒩[1]
    NG_PP = 𝒩[4]
    Coal_PP = 𝒩[5]
    CO2_stor = 𝒩[6]
    demand = 𝒩[7]

    ℒ = get_links(case)

    objective_TwoLevel = objective_value(m)

    # Check for the objective value
    # (*2 compared to 0.6.0 due to change in strategic period duration)
    # (-10400 = 2*10*(160+140+120+100) compared to 0.8.3 due to inclusion of co2 emissions)
    @test objective_value(m) ≈ -99383.3860

    # Check for the total number of variables
    # (+ 16 compared to 0.6.x as increase in storage variables)
    @test size(all_variables(m))[1] == 1128

    # Check that total emissions of both methane and CO2 are within the constraint
    # - constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
    @test all(
        value.(m[:emissions_strategic])[t_inv, CO2] <=
        EMB.emission_limit(modeltype, CO2, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ
    )
    @test all(
        value.(m[:emissions_strategic])[t_inv, NG] <= EMB.emission_limit(modeltype, NG, t_inv)
        for t_inv ∈ 𝒯ᴵⁿᵛ
    )

    # Check that the total and strategic emissions are correctly calculated
    # - constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
    @test all(
        value.(m[:emissions_strategic][t_inv, CO2]) ≈
        sum(value.(m[:emissions_total][t, CO2]) * scale_op_sp(t_inv, t) for t ∈ t_inv) for
        t_inv ∈ 𝒯ᴵⁿᵛ, atol ∈ TEST_ATOL
    )
    @test all(
        value.(m[:emissions_total][t, CO2]) ≈
        sum(value.(m[:emissions_node][n, t, CO2]) for n ∈ 𝒩ᵉᵐ) for t ∈ 𝒯, atol ∈ TEST_ATOL
    )

    # Check that the objective value is properly calculated
    # - objective(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
    @test -sum(
        (
            sum(
                value.(m[:opex_var][n, t_inv]) + value.(m[:opex_fixed][n, t_inv])
            for n ∈ 𝒩ᵒᵖᵉˣ) +
            sum(
                value.(m[:emissions_total][t, CO2]) * emission_price(modeltype, CO2, t) *
                scale_op_sp(t_inv, t) for t ∈ t_inv)
        ) * duration_strat(t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ
    ) ≈ objective_value(m) atol = TEST_ATOL

    # Check that the inlet and outlet flowrates in the links are correctly calculated
    # based on the inlet and outlet flowrats of the nodes
    # - constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)
    for n ∈ 𝒩
        ℒᶠʳᵒᵐ, ℒᵗᵒ = EMB.link_sub(ℒ, n)
        # Constraint for output flowrate and input links.
        if has_output(n)
            @test all(
                value.(m[:flow_out][n, t, p]) ≈
                sum(value.(m[:link_in][l, t, p]) for l ∈ ℒᶠʳᵒᵐ if p ∈ inputs(l.to)) for
                t ∈ 𝒯, p ∈ outputs(n), atol ∈ TEST_ATOL
            )
        end
        # Constraint for input flowrate and output links.
        if has_input(n)
            @test all(
                value.(m[:flow_in][n, t, p]) ≈
                sum(value.(m[:link_out][l, t, p]) for l ∈ ℒᵗᵒ if p ∈ outputs(l.from)) for
                t ∈ 𝒯, p ∈ inputs(n), atol ∈ TEST_ATOL
            )
        end
    end

    # Check that the total energy balances are fulfilled in the availability node for
    # each resource
    # - create_node(m, n::Availability, 𝒯, 𝒫, modeltype::EnergyModel)
    @test all(
        value.(m[:flow_in][avail, t, p]) ≈ value.(m[:flow_out][avail, t, p]) for t ∈ 𝒯,
        p ∈ 𝒫, atol ∈ TEST_ATOL
    )

    # Check that the link balance is correct
    # - create_link(m, 𝒯, 𝒫, l, formulation::Formulation)
    @test all(
        all(
            value.(m[:link_out][l, t, p]) ≈ value.(m[:link_in][l, t, p]) for t ∈ 𝒯,
            p ∈ EMB.link_res(l), atol ∈ TEST_ATOL
        ) for l ∈ ℒ, atol ∈ TEST_ATOL
    )

    # Test that the results are exactly the same for an equivalent `TwoLevelTree`
    𝒯 = TwoLevelTree(2, [2, 2, 2], SimpleTimes(4, 2), op_per_strat = 8.0)
    case, modeltype = generate_data(; 𝒯)
    m = run_model(case, modeltype, HiGHS.Optimizer)
    @test objective_TwoLevel ≈ objective_value(m)
end

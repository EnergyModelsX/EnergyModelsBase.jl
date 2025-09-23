
@testset "Test OperationalModel" begin

    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(em_data, em_cap, em_price)
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(0),
            FixedProfile(0),
            Dict(Power => 1),
            [em_data],
        )
        sink = RefSink(
            "sink",
            FixedProfile(4),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(100)),
            Dict(Power => 1),
        )

        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat = 10)

        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(Dict(CO2 => em_cap), Dict(CO2 => em_price), CO2)
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    function general_tests(m, case)
        # Extract parameters
        𝒯 = get_time_struct(case)
        sink = get_nodes(case)[2]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Test that the system produces
        # Test that the deficit is hence larger than 0 in a strategic period
        @test all(
            sum(value.(m[:cap_use][sink, t]) for t ∈ t_inv) > TEST_ATOL for t_inv ∈ 𝒯ᴵⁿᵛ
        )
    end

    @testset "Emission cap" begin
        # Test that the emission cap is enforced in the case when it may lead to a deficit
        cap = 30.0      # Emission cap in a strategic period
        em_data = EmissionsProcess(Dict(CO2 => 1.0))
        em_cap = FixedProfile(cap)
        em_price = FixedProfile(0)

        # Solve the system and extract parameters
        m, case, model = simple_graph(em_data, em_cap, em_price)
        𝒯 = get_time_struct(case)
        sink = get_nodes(case)[2]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Conduct the general tests
        general_tests(m, case)

        # Test that the strategic emission limits hold
        # - constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test all(
            value.(m[:emissions_strategic][t_inv, CO2]) ≈ cap for t_inv ∈ 𝒯ᴵⁿᵛ,
            atol ∈ TEST_ATOL
        )
        # Test that the deficit is hence larger than 0 in a strategic period
        @test all(
            sum(value.(m[:sink_deficit][sink, t]) for t ∈ t_inv) > TEST_ATOL for
            t_inv ∈ 𝒯ᴵⁿᵛ
        )
    end

    @testset "Emission price" begin
        # Test that the price for emissions is correctly calculated when there is not deficit
        cap = 40.0      # Emission cap in a strategic period
        price = 1.0     # Emission price per emitted unit of CO2
        em_data = EmissionsProcess(Dict(CO2 => 1.0))
        em_cap = FixedProfile(cap)
        em_price = FixedProfile(price)

        m, case, model = simple_graph(em_data, em_cap, em_price)
        𝒯 = get_time_struct(case)
        sink = get_nodes(case)[2]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Conduct the general tests
        general_tests(m, case)

        # Check that the objective value is correctly calculated
        # The multiplication with 2*2 is given through the number of strategic periods (2)
        # and the duration of a strategic period (2)
        @test objective_value(m) ≈ -cap * price * 2 * 2 atol = TEST_ATOL

        # Check that there is no deficit
        @test all(value.(m[:sink_deficit][sink, t]) ≤ TEST_ATOL for t ∈ 𝒯)
    end
end

@testset "create_model" begin
    """
        simple_graph()

    Creates a simple test case for testing that the deprecation is working correctly.
    """
    function simple_graph()
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(2),
            FixedProfile(10),
            Dict(Power => 1.5),
        )
        sink = RefSink(
            "sink",
            OperationalProfile([6, 8, 10, 6, 8]),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
            Dict(Power => 1),
        )
        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        op_per_strat = 10
        T = TwoLevel(2, 2, ops; op_per_strat)

        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )

        # Input data structures
        case_old = Dict(:T => T, :nodes => nodes, :links => links, :products => resources)
        case_new = Case(
            T,
            resources,
            [nodes, links],
            [[get_nodes, get_links]],
        )
        return case_new, case_old, model
    end
    # Receive the case descriptions
    case_new, case_old, model = simple_graph()

    # Create models based on both input and optimize it
    m_new = run_model(case_new, model, HiGHS.Optimizer)
    m_old_1 = run_model(case_old, model, HiGHS.Optimizer)
    m_old_2 = create_model(case_old, model)
    set_optimizer(m_old_2, HiGHS.Optimizer)
    set_optimizer_attribute(m_old_2, MOI.Silent(), true)
    optimize!(m_old_2)

    # Test that the results are the same
    @test objective_value(m_old_1) ≈ objective_value(m_new)
    @test size(all_variables(m_old_1))[1] == size(all_variables(m_new))[1]
    @test objective_value(m_old_2) ≈ objective_value(m_new)
    @test size(all_variables(m_old_2))[1] == size(all_variables(m_new))[1]
end

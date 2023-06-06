
Power = ResourceCarrier("Power", 0.0)
CO2 = ResourceEmit("CO2", 1.0)

function simple_graph(source::EMB.Source, sink::EMB.Sink)

    resources = [Power, CO2]
    T = TwoLevel(2, 2, SimpleTimes(5, 2))

    nodes = [source, sink]
    links = [Direct(12, source, sink)]
    model = OperationalModel(Dict(CO2 => FixedProfile(100)), CO2)
    case = Dict(
                :T => T,
                :nodes => nodes,
                :links => links,
                :products => resources,
    )
    return run_model(case, model, HiGHS.Optimizer), case, model
end


@testset "Test RefSink" begin

    source = RefSource(1,
                        FixedProfile(4),
                        FixedProfile(10),
                        FixedProfile(0),
                        Dict(Power => 1),
                        []
    )

    @testset "Checks :Surplus/:Deficit" begin
        
        # Test that an inconsistent Sink.Penalty dict is caught by the checks.
        sink = RefSink(2,
                        FixedProfile(3),
                        Dict(:surplus => FixedProfile(4), :def => FixedProfile(2)),
                        Dict(Power => 1)
        )
        @test_throws AssertionError simple_graph(source, sink)

        # The penalties in this Sink node lead to an infeasible optimum. Test that the 
        # checks forbids it.
        sink = RefSink(2,
                        FixedProfile(3),
                        Dict(:Surplus => FixedProfile(-4), :Deficit => FixedProfile(2)),
                        Dict(Power => 1)
        )
        @test_throws AssertionError simple_graph(source, sink)

        # The penalties in this Sink node are valid, and should lead to an optimal solution.
        sink = RefSink(2,
                        FixedProfile(3),
                        Dict(:Surplus => FixedProfile(-4), :Deficit => FixedProfile(4)),
                        Dict(Power => 1)
        )
        m, case, model = simple_graph(source, sink)
        @test termination_status(m) == MOI.OPTIMAL        
    end

    @testset "Surplus/deficit calculations" begin
        
        # Test that the deficit values are properly calculated and time is involved
        # in the penalty calculation
        source = RefSource(1,
                        FixedProfile(4),
                        FixedProfile(0),
                        FixedProfile(10),
                        Dict(Power => 1),
                        []
        )
        sink = RefSink(2,
                        FixedProfile(8),
                        Dict(:Surplus => FixedProfile(4), :Deficit => FixedProfile(10)),
                        Dict(Power => 1),
        )
        m, case, model = simple_graph(source, sink)
        𝒯       = case[:T]
        𝒯ᴵⁿᵛ    = strategic_periods(𝒯)
        @test sum(value.(m[:sink_deficit][sink, t] for t ∈ 𝒯)) ≈ 
                    length(𝒯)*4 atol = TEST_ATOL
        @test sum(value.(m[:opex_var][sink, t_inv]) ≈ 
                    sum(value.(m[:sink_deficit][sink, t])*duration(t)*sink.Penalty[:Deficit][t] for t ∈ t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ)  ==
                    𝒯.len

        # Test that the surplus values are properly calculated and time is involved
        # in the penalty calculation
        sink = RefSink(2,
                        FixedProfile(2),
                        Dict(:Surplus => FixedProfile(-100), :Deficit => FixedProfile(100)),
                        Dict(Power => 1),
        )
        m, case, model = simple_graph(source, sink)
        𝒯       = case[:T]
        𝒯ᴵⁿᵛ    = strategic_periods(𝒯)
        @test sum(value.(m[:sink_surplus][sink, t]) for t ∈ 𝒯) ≈ 
                    length(𝒯)*2 atol = TEST_ATOL
        @test sum(value.(m[:opex_var][sink, t_inv]) ≈ 
                    sum(value.(m[:sink_surplus][sink, t])*duration(t)*sink.Penalty[:Surplus][t] for t ∈ t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
                    𝒯.len
            
    end


    @testset "Process emissions" begin
        
        # Test that the if there are no emissions associated, then they are set to 0
        source = RefSource(1,
                        FixedProfile(4),
                        FixedProfile(0),
                        FixedProfile(10),
                        Dict(Power => 1),
                        []
        )
        sink = RefSink(2,
                        FixedProfile(3),
                        Dict(:Surplus => FixedProfile(4), :Deficit => FixedProfile(100)),
                        Dict(Power => 1),
        )
        m, case, model = simple_graph(source, sink)
        𝒯       = case[:T]
        @test sum(value.(m[:emissions_node][source, t, CO2]) for t ∈ 𝒯) ≈ 0 atol = TEST_ATOL
        @test sum(value.(m[:emissions_node][sink, t, CO2]) for t ∈ 𝒯) ≈ 0 atol = TEST_ATOL

        # Test that the emissions from a sink node with emissions are properly accounted for
        sink_emit = RefSink(2,
                        FixedProfile(3),
                        Dict(:Surplus => FixedProfile(4), :Deficit => FixedProfile(100)),
                        Dict(Power => 1),
                        Dict(CO2 => 10),
        )
        m, case, model = simple_graph(source, sink_emit)
        𝒯       = case[:T]
        𝒯ᴵⁿᵛ    = strategic_periods(𝒯)
        T_total = sum(sum(duration(t) for t ∈ t_inv)*duration(t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test sum(sum(value.(m[:cap_use][sink_emit, t])*duration(t)*sink_emit.Emissions[CO2] for t ∈ t_inv) ≈ 
                    model.Emission_limit[CO2][t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) == 𝒯.len
        @test sum(sum(value.(m[:emissions_node][sink_emit, t, CO2])*duration(t) for t ∈ t_inv) ≈ 
                    model.Emission_limit[CO2][t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) == 𝒯.len

        # Test that the emissions from a sink node with emissions are properly accounted for
        source_emit = RefSource(1,
                            FixedProfile(4),
                            FixedProfile(0),
                            FixedProfile(10),
                            Dict(Power => 1),
                            [],
                            Dict(CO2 => 10),
        )
        m, case, model = simple_graph(source_emit, sink)
        𝒯       = case[:T]
        𝒯ᴵⁿᵛ    = strategic_periods(𝒯)
        T_total = sum(sum(duration(t) for t ∈ t_inv)*duration(t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test sum(sum(value.(m[:cap_use][source_emit, t])*duration(t)*source_emit.Emissions[CO2] for t ∈ t_inv) ≈ 
                    model.Emission_limit[CO2][t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) == 𝒯.len
        @test sum(sum(value.(m[:emissions_node][source_emit, t, CO2])*duration(t) for t ∈ t_inv) ≈ 
                    model.Emission_limit[CO2][t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) == 𝒯.len

    end
end
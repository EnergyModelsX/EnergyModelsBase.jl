using TimeStructures

const TS = TimeStructures
const EMB = EnergyModelsBase


Power = ResourceCarrier("Power", 1.0)
CO2 = ResourceEmit("CO2", 1.0)


function simple_graph(source::EMB.Source, sink::EMB.Sink)
    # emissions   = Dict(CO2=>0.01)
    resources = [Power]
    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 6, 1))

    nodes = [source, sink]
    links = [Direct(12, source, sink)]
    case = Dict(:T => T, :nodes => nodes, :links => links, :products => resources,
        :global_data => GlobalData(Dict(CO2 => FixedProfile(100))))

    return run_model(case)
end


@testset "Test RefSink" begin

    source = RefSource(1, FixedProfile(1), FixedProfile(10), FixedProfile(10),
        Dict(Power => 1), Dict(CO2 => 0), Dict("" => EmptyData()))


    @testset "Checks :Surplus/:Deficit" begin
        
        # Test that an inconsistent Sink.Penalty dict is caught by the checks.
        sink = RefSink(2, FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :sur => FixedProfile(2)), Dict(Power => 1), Dict(CO2 => 0))
        @test_throws AssertionError simple_graph(source, sink)

        # The penalties in this Sink node lead to an infeasible optimum. Test that the 
        # checks forbids it.
        sink = RefSink(2, FixedProfile(3),
            Dict(:Surplus => -1 * FixedProfile(4), :Deficit => 1 * FixedProfile(3)),
            Dict(Power => 1), Dict(CO2 => 0))
        @test_throws AssertionError simple_graph(source, sink)

        # The penalties in this Sink node is valid, and should lead to an optimal solution.
        sink = RefSink(2, FixedProfile(3),
            Dict(:Surplus => -1 * FixedProfile(4), :Deficit => 1 * FixedProfile(4)),
            Dict(Power => 1), Dict(CO2 => 0))
        m = simple_graph(source, sink)
        @test termination_status(m) == MOI.OPTIMAL
        
    end
end
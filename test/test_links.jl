
@testset "Link utilities" begin

    # Resources used in the analysis
    NG = ResourceEmit("NG", 0.2)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph()
        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(NG => 1),
        )
        network = RefNetworkNode(
            "network",
            FixedProfile(25),
            FixedProfile(5.5),
            FixedProfile(0),
            Dict(NG => 2),
            Dict(Power => 1),
            Data[EmissionsEnergy()],
        )

        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
        )

        resources = [NG, Power, CO2]
        ops = SimpleTimes(5, 2)
        op_per_strat = 10
        T = TwoLevel(2, 2, ops; op_per_strat)

        nodes = [source, network, sink]
        links = [
            Direct(12, source, network)
            Direct(23, network, sink)
            Direct(23, source, sink)
        ]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100), NG => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0), NG => FixedProfile(0)),
            CO2,
        )
        case = Dict(:T => T, :nodes => nodes, :links => links, :products => resources)
        return case, model
    end

    @testset "Access functions" begin
        case, model = simple_graph()
        ℒ = case[:links]
        𝒩 = case[:nodes]

        # Test that the tranported resources are correctly identified
        @test inputs(ℒ[1]) == outputs(𝒩[1])
        @test outputs(ℒ[1]) == inputs(𝒩[2])

        # Test that the function `link_res` does not return a transported resources for the
        # 3ʳᵈ link
        @test isempty(EMB.link_res(ℒ[3]))

        # Test that the constructor for a direct link is working and that the function
        # formulation is working
        @test isa(formulation(ℒ[1]), Linear)
    end
end

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

    @testset "Identification functions" begin
        case, model = simple_graph()
        ℒ = case[:links]

        # Test that all links are identified as unidirectional
        @test all(is_unidirectional(l) for l ∈ ℒ)

        # Test that all links do not have emissions
        @test !all(has_emissions(l) for l ∈ ℒ)
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
        @test isempty(EMB.link_res(ℒ[3]))

        # Test that the constructor for a direct link is working and that the function
        # formulation is working
        @test isa(formulation(ℒ[1]), Linear)
    end

    @testset "Variable declaration" begin
        case, model = simple_graph()
        m = create_model(case, model)
        ℒ = case[:links]
        𝒯 = case[:T]

        # Test that all link variables have a lower bound of 0
        @test all(
            all(lower_bound(m[:link_in][l, t, p]) == 0 for p ∈ inputs(l))
            for l ∈ ℒ, t ∈ 𝒯
        )
        @test all(
            all(lower_bound(m[:link_out][l, t, p]) == 0 for p ∈ outputs(l))
            for l ∈ ℒ, t ∈ 𝒯
        )

        # Test that `emissions_link` variable is empty
        @test isempty(m[:emissions_link])
    end
end

@testset "Link emissions" begin
    # Creation of a new link type with associated emissions in each operational period
    struct EmissionDirect <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
    end
    function EMB.create_link(m, 𝒯, 𝒫, l::EmissionDirect, formulation::EMB.Formulation)

        # Generic link in which each output corresponds to the input
        @constraint(m, [t ∈ 𝒯, p ∈ EMB.link_res(l)],
            m[:link_out][l, t, p] == m[:link_in][l, t, p]
        )

        # Emissions
        𝒫ᵉᵐ = filter(EMB.is_resource_emit, 𝒫)
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_link][l, t, p_em] == 0.1
        )
    end
    EMB.has_emissions(l::EmissionDirect) = true

    # Resources used in the analysis
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
            Dict(Power => 1),
        )
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
        )

        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        op_per_strat = 10
        T = TwoLevel(2, 2, ops; op_per_strat)

        nodes = [source, sink]
        links = [
            EmissionDirect(23, source, sink, Linear())
        ]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Dict(:T => T, :nodes => nodes, :links => links, :products => resources)
        return case, model
    end

    case, model = simple_graph()
    m = run_model(case, model, HiGHS.Optimizer)
    ℒ = case[:links]
    𝒩 = case[:nodes]
    𝒯 = case[:T]

    # Test that `emissions_link` variable is not empty
    @test !isempty(m[:emissions_link])

    # Test that the value of the emission variable is included in the total emissions
    @test all(
        value.(m[:emissions_total][t, CO2]) ==
        value.(m[:emissions_link][ℒ[1], t, CO2])
    for t ∈ 𝒯)
    @test all(value.(m[:emissions_total][t, CO2]) == 0.1 for t ∈ 𝒯)
end

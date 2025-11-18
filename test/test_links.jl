@testset "Link - utilities" begin

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
            ExtensionData[EmissionsEnergy()],
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
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return case, model
    end

    @testset "Identification functions" begin
        case, model = simple_graph()
        ℒ = get_links(case)

        # Test that all links are identified as unidirectional
        @test all(is_unidirectional(l) for l ∈ ℒ)

        # Test that all links do not have emissions
        @test !any(has_emissions(l) for l ∈ ℒ)

        # Test that all links do not have opex variables
        @test !any(has_opex(l) for l ∈ ℒ)
    end

    @testset "Access functions" begin
        case, model = simple_graph()
        ℒ = get_links(case)
        𝒩 = get_nodes(case)

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
        ℒ = get_links(case)
        𝒯 = get_time_struct(case)

        # Test that all link variables have a lower bound of 0
        @test all(
            all(lower_bound(m[:link_in][l, t, p]) == 0 for p ∈ inputs(l))
            for l ∈ ℒ, t ∈ 𝒯
        )
        @test all(
            all(lower_bound(m[:link_out][l, t, p]) == 0 for p ∈ outputs(l))
            for l ∈ ℒ, t ∈ 𝒯
        )

        # Test that `emissions_link`, `link_opex_var`, `link_opex_fixed`, and `link_cap_inst`
        #are empty
        @test isempty(m[:emissions_link])
        @test isempty(m[:link_opex_var])
        @test isempty(m[:link_opex_fixed])
        @test isempty(m[:link_cap_inst])
    end
end

# Resources used in the analysis
Power = ResourceCarrier("Power", 0.0)
CO2 = ResourceEmit("CO2", 1.0)

# Function for setting up the system
function link_graph(LinkType::Vector{DataType}; res_in=Power, res_out=Power)
    # Used source, network, and sink
    source = RefSource(
        "source",
        FixedProfile(4),
        FixedProfile(10),
        FixedProfile(0),
        Dict(res_in => 1),
    )
    sink = RefSink(
        "sink",
        FixedProfile(3),
        Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
        Dict(res_out => 1),
    )

    resources = [Power, CO2]
    ops = SimpleTimes(5, 2)
    op_per_strat = 10
    T = TwoLevel(2, 2, ops; op_per_strat)

    nodes = [source, sink]
    links = Link[link_type(string(link_type), source, sink, Linear()) for link_type ∈ LinkType]
    model = OperationalModel(
        Dict(CO2 => FixedProfile(100)),
        Dict(CO2 => FixedProfile(0)),
        CO2,
    )
    case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
    return run_model(case, model, HiGHS.Optimizer), case, model
end

@testset "Link - different resources" begin
    # Creation of a new link type with associated emissions in each operational period
    struct ResourceLink <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
    end
    function EMB.create_link(m, l::ResourceLink, 𝒯, 𝒫, modeltype::EnergyModel)
        # Generic link in which each output corresponds to the input
        @constraint(m, [t ∈ 𝒯],
            sum(m[:link_out][l, t, p_out] for p_out ∈ outputs(l)) ==
                sum(m[:link_in][l, t, p_in] for p_in ∈ inputs(l))
        )
    end
    EMB.inputs(l::ResourceLink) = [Power]
    EMB.outputs(l::ResourceLink) = [CO2]

    # Create and solve the system
    m, case, model = link_graph([ResourceLink]; res_out=CO2)
    ℒ = get_links(case)
    𝒩 = get_nodes(case)
    𝒯 = get_time_struct(case)

    # Test that the coupling is working correctly and resources are transported
    @test all(value.(m[:flow_out][𝒩[1], t, Power]) ≈ value.(m[:link_in][ℒ[1], t, Power]) for t ∈ 𝒯)
    @test all(value.(m[:flow_in][𝒩[2], t, CO2]) ≈ value.(m[:link_out][ℒ[1], t, CO2]) for t ∈ 𝒯)
    @test all(value.(m[:flow_out][𝒩[1], t, Power]) ≈ value.(m[:flow_in][𝒩[2], t, CO2]) for t ∈ 𝒯)
    @test all(value.(m[:flow_out][𝒩[1], t, Power]) ≈ 3 for t ∈ 𝒯)
end

@testset "Link - emissions" begin
    # Creation of a new link type with associated emissions in each operational period
    struct EmissionDirect <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
    end
    function EMB.create_link(m, l::EmissionDirect, 𝒯, 𝒫, modeltype::EnergyModel)
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

    # Create and solve the system
    m, case, model = link_graph([EmissionDirect])
    ℒ = get_links(case)
    𝒩 = get_nodes(case)
    𝒯 = get_time_struct(case)

    # Test that `emissions_link` variable is not empty
    @test !isempty(m[:emissions_link])

    # Test that the value of the emission variable is included in the total emissions
    @test all(
        value.(m[:emissions_total][t, CO2]) ==
        value.(m[:emissions_link][ℒ[1], t, CO2])
    for t ∈ 𝒯)
    @test all(value.(m[:emissions_total][t, CO2]) == 0.1 for t ∈ 𝒯)
end

@testset "Link - OPEX" begin
    # Creation of a new link type with associated OPEX
    struct OpexDirect <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
    end
    function EMB.create_link(m, l::OpexDirect, 𝒯, 𝒫, modeltype::EnergyModel)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Generic link in which each output corresponds to the input
        @constraint(m, [t ∈ 𝒯, p ∈ EMB.link_res(l)],
            m[:link_out][l, t, p] == m[:link_in][l, t, p]
        )

        # Variable OPEX calculation
        @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:link_opex_var][l, t_inv] == 0.2)
        @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:link_opex_fixed][l, t_inv] == 1)
    end
    EMB.has_opex(l::OpexDirect) = true

    # Create and solve the system
    m, case, model = link_graph([OpexDirect])
    ℒ = get_links(case)
    𝒩 = get_nodes(case)
    𝒯 = get_time_struct(case)

    # Test that `link_opex_var` and `link_opex_fixed` are not empty
    @test !isempty(m[:link_opex_var])
    @test !isempty(m[:link_opex_fixed])

    # Test that the values are included in the objective function
    #   3 * 10 * 10     is the cost of the source Node
    #   0.2             is the variable OPEX contribution from the link
    #   1               is the fixed OPEX contribution from the link
    # The multiplication with 2 * 2 is due to 2 strategic periods with a duration of 2
    @test objective_value(m) ≈ -((3 * 10 * 10) + 0.2 + 1) * (2 * 2) atol=TEST_ATOL
end

@testset "Link - capacity" begin
    # Creation of a new link type with associated capacity
    struct CapDirect <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
    end
    function EMB.create_link(m, l::CapDirect, 𝒯, 𝒫, modeltype::EnergyModel)

        # Generic link in which each output corresponds to the input
        @constraint(m, [t ∈ 𝒯, p ∈ EMB.link_res(l)],
            m[:link_out][l, t, p] == m[:link_in][l, t, p]
        )

        # Capacity constraint
        @constraint(m, [t ∈ 𝒯, p ∈ EMB.link_res(l)],
            m[:link_out][l, t, p] ≤ m[:link_cap_inst][l, t]
        )
        constraints_capacity_installed(m, l, 𝒯, modeltype)
    end
    EMB.capacity(l::CapDirect, t) = OperationalProfile([2, 3, 3, 2, 1])[t]
    EMB.has_capacity(l::CapDirect) = true

    # Create and solve the system
    m, case, model = link_graph([CapDirect])
    ℒ = get_links(case)
    𝒩 = get_nodes(case)
    𝒯 = get_time_struct(case)

    # Helper for usage
    cap = OperationalProfile([2, 3, 3, 2, 1])
    deficit = OperationalProfile([1, 0, 0, 1, 2])

    # Test that `link_cap_inst` is not empty
    @test !isempty(m[:link_cap_inst])

    # Test that the capacity is restricted, impacting the different nodes
    @test all(value.(m[:cap_use][𝒩[1], t]) == cap[t] for t ∈ 𝒯)
    @test all(value.(m[:cap_use][𝒩[2], t]) == cap[t] for t ∈ 𝒯)
    @test all(value.(m[:sink_deficit][𝒩[2], t]) == deficit[t] for t ∈ 𝒯)
    @test all(value.(m[:link_in][ℒ[1], t, Power]) == cap[t] for t ∈ 𝒯)
    @test all(value.(m[:link_out][ℒ[1], t, Power]) == cap[t] for t ∈ 𝒯)
end

@testset "Link - variable creation" begin
    # Creation of a new link types
    abstract type DirectSub <: Link end
    struct DirectSub1 <: DirectSub
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
    end
    struct DirectSub2 <: DirectSub
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
    end

    struct Direct1 <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
    end

    function EMB.variables_link(m, ℒˢᵘᵇ::Vector{<:DirectSub}, 𝒯, modeltype::EnergyModel)
        @variable(m, test_var_sub[ℒˢᵘᵇ, 𝒯])
    end
    function EMB.variables_link(m, ℒˢᵘᵇ::Vector{<:DirectSub1}, 𝒯, modeltype::EnergyModel)
        @variable(m, test_var_sub_1[ℒˢᵘᵇ, 𝒯])
    end
    function EMB.variables_link(m, ℒˢᵘᵇ::Vector{<:Direct1}, 𝒯, modeltype::EnergyModel)
        @variable(m, test_var_1[ℒˢᵘᵇ, 𝒯])
    end

    # Create and solve the system
    m, case, model = link_graph([DirectSub1, DirectSub2, Direct1])
    ℒ = get_links(case)
    𝒩 = get_nodes(case)
    𝒯 = get_time_struct(case)

    # Test that `test_var_sub`, `test_var_sub_1`, and `test_var_1` are created
    @test haskey(object_dictionary(m), :test_var_sub)
    @test haskey(object_dictionary(m), :test_var_sub_1)
    @test haskey(object_dictionary(m), :test_var_1)

    # Test that the variables are `test_var_sub`, `test_var_sub_1`, and `test_var_1` are
    # created for the corresponding links
    @test size(m[:test_var_sub]) == (2,10)
    @test size(m[:test_var_sub_1]) == (1,10)
    @test size(m[:test_var_1]) == (1,10)
end

@testset "Variable creation" begin
    # New data type including 2 subtypes
    abstract type ExampleData <: ExtensionData end
    struct ExampleDataA <: ExampleData
    end
    struct ExampleDataB <: ExampleData
    end

    # Creation of a data link type with associated OPEX
    struct DataDirect <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
        data::Vector{<:ExtensionData}
    end

    EMB.element_data(l::DataDirect) = l.data

    # Subfunctions for the nodes
    function EMB.variables_ext_data(m, _::Type{<:ExampleData}, 𝒳ᵈᵃᵗ::Vector{<:EMB.Node}, 𝒯, 𝒫, modeltype::EnergyModel)
        @variable(m, node_example[𝒳ᵈᵃᵗ, 𝒯] ≥ 0)
    end
    function EMB.variables_ext_data(m, _::Type{ExampleDataB}, 𝒳ᵈᵃᵗ::Vector{<:EMB.Node}, 𝒯, 𝒫, modeltype::EnergyModel)
        @variable(m, node_example_b[𝒳ᵈᵃᵗ, 𝒯] ≥ 0)
    end

    # Subfunctions for the link
    function EMB.variables_ext_data(m, _::Type{<:ExampleDataA}, 𝒳ᵈᵃᵗ::Vector{<:Link}, 𝒯, 𝒫, modeltype::EnergyModel)
        @variable(m, link_example_a[𝒳ᵈᵃᵗ, 𝒯] ≥ 0)
    end
    function EMB.variables_ext_data(m, _::Type{<:ExampleDataB}, 𝒳ᵈᵃᵗ::Vector{<:Link}, 𝒯, 𝒫, modeltype::EnergyModel)
        @variable(m, link_example_b[𝒳ᵈᵃᵗ, 𝒯] ≥ 0)
    end
    function EMB.create_link(m, l::DataDirect, 𝒯, 𝒫, modeltype::EnergyModel)
        # Generic link in which each output corresponds to the input
        @constraint(m, [t ∈ 𝒯, p ∈ EMB.link_res(l)],
            m[:link_out][l, t, p] == m[:link_in][l, t, p]
        )
    end

    # Resources used in the analysis
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph()
        # Define the different resources
        NG = ResourceEmit("NG", 0.2)
        Coal = ResourceCarrier("Coal", 0.35)
        Power = ResourceCarrier("Power", 0.0)
        CO2 = ResourceEmit("CO2", 1.0)
        products = [NG, Coal, Power, CO2]

        # Creation of the emission data for the individual nodes.
        capture_data = CaptureEnergyEmissions(0.9)
        emission_data = EmissionsEnergy()

        # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
        # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO2 storage.
        nodes = [
            GenAvailability(1, products),
            RefSource(2, FixedProfile(1e12), FixedProfile(30), FixedProfile(0), Dict(NG => 1), ExtensionData[ExampleDataA()]),
            RefSource(3, FixedProfile(1e12), FixedProfile(9), FixedProfile(0), Dict(Coal => 1), ExtensionData[ExampleDataB()]),
            RefNetworkNode(
                4,
                FixedProfile(25),
                FixedProfile(5.5),
                FixedProfile(5),
                Dict(NG => 2),
                Dict(Power => 1, CO2 => 1),
                [capture_data, ExampleDataA()],
            ),
            RefNetworkNode(
                5,
                FixedProfile(25),
                FixedProfile(6),
                FixedProfile(10),
                Dict(Coal => 2.5),
                Dict(Power => 1),
                [emission_data, ExampleDataB()],
            ),
            RefStorage{AccumulatingEmissions}(
                6,
                StorCapOpex(FixedProfile(60), FixedProfile(9.1), FixedProfile(0)),
                StorCap(FixedProfile(600)),
                CO2,
                Dict(CO2 => 1, Power => 0.02),
                Dict(CO2 => 1),
                ExtensionData[ExampleDataB()],
            ),
            RefSink(
                7,
                OperationalProfile([20, 30, 40, 30]),
                Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
                Dict(Power => 1),
            ),
        ]

        # Connect all nodes with the availability node for the overall energy/mass balance
        links = [
            DataDirect(14, nodes[1], nodes[4], Linear(), ExtensionData[ExampleDataA()])
            Direct(15, nodes[1], nodes[5], Linear())
            Direct(16, nodes[1], nodes[6], Linear())
            Direct(17, nodes[1], nodes[7], Linear())
            Direct(21, nodes[2], nodes[1], Linear())
            DataDirect(31, nodes[3], nodes[1], Linear(), ExtensionData[ExampleDataB()])
            Direct(41, nodes[4], nodes[1], Linear())
            Direct(51, nodes[5], nodes[1], Linear())
            Direct(61, nodes[6], nodes[1], Linear())
        ]

        # Creation of the time structure and global data
        T = TwoLevel(4, 2, SimpleTimes(4, 2), op_per_strat = 8)
        model = OperationalModel(
            Dict(CO2 => StrategicProfile([160, 140, 120, 100]), NG => FixedProfile(1e6)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )

        # Input data structure
        case = Case(T, products, [nodes, links], [[get_nodes, get_links]])
        return case, model
    end

    # Create the case and the model
    case, model = simple_graph()
    m = create_model(case, model)

    # Extract data from the case
    𝒩 = get_nodes(case)
    ℒ = get_links(case)
    𝒯 = get_time_struct(case)

    @testset "Node data" begin
        # Test that the variables_ext_data function for the abstract type is included for all subtypes
        @test haskey(m, :node_example)
        @test sum(nt[1] == 𝒩[2] for nt ∈ keys(m[:node_example])) == length(𝒯)
        @test sum(nt[1] == 𝒩[3] for nt ∈ keys(m[:node_example])) == length(𝒯)
        @test sum(nt[1] == 𝒩[4] for nt ∈ keys(m[:node_example])) == length(𝒯)
        @test sum(nt[1] == 𝒩[6] for nt ∈ keys(m[:node_example])) == length(𝒯)

        # Test that the variables_ext_data for the concrete type is included
        @test haskey(m, :node_example_b)
        @test sum(nt[1] == 𝒩[3] for nt ∈ keys(m[:node_example_b])) == length(𝒯)
        @test sum(nt[1] == 𝒩[5] for nt ∈ keys(m[:node_example_b])) == length(𝒯)
        @test sum(nt[1] == 𝒩[6] for nt ∈ keys(m[:node_example_b])) == length(𝒯)
    end


    @testset "Link data" begin
        @test haskey(m, :link_example_a)
        @test sum(nt[1] == ℒ[1] for nt ∈ keys(m[:link_example_a])) == length(𝒯)

        @test haskey(m, :link_example_b)
        @test sum(nt[1] == ℒ[6] for nt ∈ keys(m[:link_example_b])) == length(𝒯)
    end
end

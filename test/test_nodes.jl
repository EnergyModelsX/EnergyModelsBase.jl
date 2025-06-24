@testset "Node utilities" begin

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
            RefSource(2, FixedProfile(1e12), FixedProfile(30), FixedProfile(0), Dict(NG => 1)),
            RefSource(3, FixedProfile(1e12), FixedProfile(9), FixedProfile(0), Dict(Coal => 1)),
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
        links = [
            Direct(14, nodes[1], nodes[4], Linear())
            Direct(15, nodes[1], nodes[5], Linear())
            Direct(16, nodes[1], nodes[6], Linear())
            Direct(17, nodes[1], nodes[7], Linear())
            Direct(21, nodes[2], nodes[1], Linear())
            Direct(31, nodes[3], nodes[1], Linear())
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

    @testset "Identification functions" begin
        case, model = simple_graph()
        𝒩 = get_nodes(case)
        stor = 𝒩[6]

        # Test that all nodal supertypes are identified correctly
        @test [EMB.is_source(n) for n ∈ 𝒩] ==
            [false, true, true, false, false, false, false]
        @test [EMB.is_network_node(n) for n ∈ 𝒩] ==
            [true, false, false, true, true, true, false]
        @test [EMB.is_storage(n) for n ∈ 𝒩] ==
            [false, false, false, false, false, true, false]
        @test [EMB.is_sink(n) for n ∈ 𝒩] ==
            [false, false, false, false, false, false, true]

        # Test that the corrects nodes with emissions are identified
        @test [EMB.has_emissions(n) for n ∈ 𝒩] ==
            [false, false, false, true, true, true, false]

        # Test that the corrects nodes with input and output are identified
        @test [has_output(n) for n ∈ 𝒩] ==
            [true, true, true, true, true, true, false]
        @test [has_input(n) for n ∈ 𝒩] ==
            [true, false, false, true, true, true, true]

        # Test that all nodes are identified as unidirectional
        @test all(is_unidirectional(n) for n ∈ 𝒩)

        # Test that the storage node is correctly identified
        @test all([
            has_charge(stor), EMB.has_charge_cap(stor), EMB.has_charge_OPEX_fixed(stor),
            EMB.has_charge_OPEX_var(stor),
            !EMB.has_level_OPEX_fixed(stor), !EMB.has_level_OPEX_var(stor),
            !has_discharge(stor), !EMB.has_discharge_cap(stor),
            !EMB.has_discharge_OPEX_fixed(stor), !EMB.has_discharge_OPEX_var(stor),
        ])
    end

    @testset "Access functions" begin
        case, model = simple_graph()
        𝒩 = get_nodes(case)

        # Test that the input and output resources are correctly identified
        @test outputs(𝒩[2]) == [NG]
        @test outputs(𝒩[2], NG) == 1
        @test outputs(𝒩[4]) == [CO2, Power] || outputs(𝒩[4]) == [Power, CO2]
        @test inputs(𝒩[6]) == [CO2, Power] || inputs(𝒩[6]) == [Power, CO2]
        @test inputs(𝒩[7]) == [Power]
        @test inputs(𝒩[7], Power) == 1
    end

    @testset "Variable declaration" begin
        case, model = simple_graph()
        m = create_model(case, model)

        𝒩 = get_nodes(case)
        stor = 𝒩[6]
        𝒩ⁱⁿ = filter(has_input, 𝒩)
        𝒩ᵒᵘᵗ = setdiff(filter(has_output, 𝒩), [stor]) # The storage has a fixed output variable
        𝒯 = get_time_struct(case)

        # Test that all node flow variables have a lower bound of 0
        @test all(
            all(lower_bound(m[:flow_in][n_in, t, p]) == 0 for p ∈ inputs(n_in))
        for n_in ∈ 𝒩ⁱⁿ, t ∈ 𝒯)
        @test all(
            all(lower_bound(m[:flow_out][n_out, t, p]) == 0 for p ∈ outputs(n_out))
        for n_out ∈ 𝒩ᵒᵘᵗ, t ∈ 𝒯)
    end
end


@testset "Test RefSource and RefSink" begin

    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(source::Source, sink::Sink)
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
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    @testset "General tests - RefSource" begin
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

        m, case, model = simple_graph(source, sink)
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Test that the capacity bound is properly set
        # - constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:cap_inst][source, t]) ≈ EMB.capacity(source)[t] for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the capacity bound is properly utilized for a `RefSink`
        # - constraints_capacity(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:cap_use][source, t]) <= value.(m[:cap_inst][source, t]) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the outflow is equal to the specified capacity usage
        # - constraints_flow_out(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:flow_out][source, t, Power]) ≈
            value.(m[:cap_use][source, t]) * outputs(source, Power) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the variable OPEX values are properly calculated for RefSource
        # - constraints_opex_var(m, n::Node, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][source, t_inv]) ≈ sum(
                value.(m[:cap_use][source, t]) * EMB.opex_var(source, t) * duration(t) for
                t ∈ t_inv
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        )

        # Test that the fixed OPEX values are properly calculated for RefSource
        # - constraints_opex_fixed(m, n::Node, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_fixed][source, t_inv]) ≈
            EMB.opex_fixed(source, t_inv) * value.(m[:cap_inst][source, first(t_inv)]) for
            t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        )
    end

    @testset "General tests - RefSink" begin
        # Test that the deficit values are properly calculated and time is involved
        # in the penalty calculation
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(2),
            FixedProfile(10),
            Dict(Power => 1),
        )
        sink = RefSink(
            "sink",
            FixedProfile(8),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
            Dict(Power => 1),
        )

        m, case, model = simple_graph(source, sink)
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Test that the inflow is equal to the specified capacity usage
        # - constraints_flow_in(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:flow_in][sink, t, Power]) ≈
            value.(m[:cap_use][sink, t]) * inputs(sink, Power) for t ∈ 𝒯, atol = TEST_ATOL
        )

        # Test that the mass balance is properly calculated
        # - constraints_capacity(m, n::Sink, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(value.(m[:sink_deficit][sink, t]) ≈ 4 for t ∈ 𝒯)
        @test all(
            value.(m[:sink_deficit][sink, t]) + value.(m[:cap_use][sink, t]) ≈
            value.(m[:sink_surplus][sink, t]) + value.(m[:cap_inst][sink, t]) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the fixed OPEX is set to 0
        # - constraints_opex_fixed(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(value.(m[:opex_fixed][sink, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the opex calculations are correct
        # - constraints_opex_var(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][sink, t_inv]) ≈
                sum(value.(m[:sink_deficit][sink, t]) * duration(t) * 10 for t ∈ t_inv)
        for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the surplus values are properly calculated and time is involved
        # in the penalty calculation
        sink = RefSink(
            2,
            FixedProfile(2),
            Dict(:surplus => FixedProfile(-100), :deficit => FixedProfile(100)),
            Dict(Power => 1),
        )
        m, case, model = simple_graph(source, sink)
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Test that the mass balance is properly calculated
        # - constraints_capacity(m, n::Sink, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(value.(m[:sink_surplus][sink, t]) ≈ 2 for t ∈ 𝒯)
        @test all(
            value.(m[:sink_deficit][sink, t]) + value.(m[:cap_use][sink, t]) ≈
            value.(m[:sink_surplus][sink, t]) + value.(m[:cap_inst][sink, t]) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the opex calculations are correct
        # - constraints_opex_var(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][sink, t_inv]) ≈
                sum(value.(m[:sink_surplus][sink, t]) * duration(t) * -100 for t ∈ t_inv)
        for t_inv ∈ 𝒯ᴵⁿᵛ)

    end

    @testset "Process emissions - RefSink and RefSource" begin

        # Test that the if there are no emissions associated, then no emission variables are
        # created
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(0),
            FixedProfile(10),
            Dict(Power => 1),
        )
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
        )
        m, case, model = simple_graph(source, sink)
        𝒯 = get_time_struct(case)
        @test !any(val == source for val ∈ axes(m[:emissions_node])[1])
        @test !any(val == sink for val ∈ axes(m[:emissions_node])[1])

        # Test that the emissions from a sink node with emissions are properly accounted for
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::EmissionsProcess)
        em_data = EmissionsProcess(Dict(CO2 => 10.0))
        snk_emit = RefSink(
            "sink_emit",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
            [em_data],
        )
        m, case, model = simple_graph(source, snk_emit)
        𝒯 = get_time_struct(case)
        # Test that the emissions are properly calculated
        @test all(
            value.(m[:cap_use][snk_emit, t]) * process_emissions(em_data, CO2, t) ≈
            value.(m[:emissions_node][snk_emit, t, CO2]) for t ∈ 𝒯
        )
        # Test that the emissions from a source node with emissions are properly accounted for
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::EmissionsProcess)
        em_data = EmissionsProcess(Dict(CO2 => 10.0))
        src_emit = RefSource(
            "source_emit",
            FixedProfile(4),
            FixedProfile(0),
            FixedProfile(10),
            Dict(Power => 1),
            [em_data],
        )
        m, case, model = simple_graph(src_emit, sink)
        𝒯 = get_time_struct(case)
        # Test that the emissions are properly calculated, although no input is present in
        # a `Source ndoe`
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::EmissionsProcess)
        @test all(
            value.(m[:cap_use][src_emit, t]) * process_emissions(em_data, CO2, t) ≈
            value.(m[:emissions_node][src_emit, t, CO2]) for t ∈ 𝒯
        )
    end
end

@testset "Test RefNetworkNode with various EmissionData" begin
    # Resources used in the analysis
    NG = ResourceEmit("NG", 0.2)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(; data_em = nothing)
        if typeof(data_em) <: EMB.CaptureData
            output = Dict(Power => 1, CO2 => 0)
            data_net = [data_em]
            data_source = [EmissionsProcess(Dict(CO2 => 0.5))]
        elseif typeof(data_em) <: EmissionsData
            output = Dict(Power => 1)
            data_net = [data_em]
            data_source = [EmissionsProcess(Dict(CO2 => 0.5))]
        else
            output = Dict(Power => 1)
            data_net = Vector{ExtensionData}([])
            data_source = Vector{ExtensionData}([])
        end

        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(NG => 1),
            data_source,
        )
        network = RefNetworkNode(
            "network",
            FixedProfile(25),
            FixedProfile(5.5),
            FixedProfile(0),
            Dict(NG => 2),
            Dict(output),
            data_net,
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
        ]

        if typeof(data_em) <: EMB.CaptureData
            CO2_stor = RefSink(
                "CO2 sink",
                FixedProfile(0),
                Dict(:surplus => FixedProfile(9.1), :deficit => FixedProfile(20)),
                Dict(CO2 => 1, Power => 0.02),
            )
            push!(nodes, CO2_stor)
            append!(links, [Direct(14, source, CO2_stor), Direct(24, network, CO2_stor)])
        end

        model = OperationalModel(
            Dict(CO2 => FixedProfile(100), NG => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0), NG => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    @testset "Emissions tests - wo Emissions" begin
        # Check that the overall emission balance is working and that the emissions
        # variables are only created if required.

        # Run the model and extract the data
        m, case, model = simple_graph()
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        net = 𝒩[2]

        # Check that there is production
        @test all(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯)

        # Check that no emission variables are created without emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 0

        # Check that the total and strategic emissions are 0
        # - constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test all(
            value.(m[:emissions_strategic][t_inv, CO2]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ,
            atol = TEST_ATOL
        )
        @test all(value.(m[:emissions_total][t, CO2]) ≈ 0 for t ∈ 𝒯, atol = TEST_ATOL)
        @test all(
            value.(m[:emissions_strategic][t_inv, NG]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ,
            atol = TEST_ATOL
        )
        @test all(value.(m[:emissions_total][t, NG]) ≈ 0 for t ∈ 𝒯, atol = TEST_ATOL)
    end

    @testset "Emissions tests - with energy emissions" begin
        # Check that the emissions are properly calculated when only energy emissions are
        # considered

        # Run the model and extract the data
        em_data = EmissionsEnergy()
        m, case, model = simple_graph(data_em = em_data)
        𝒩 = get_nodes(case)
        𝒩ᵉᵐ = nodes_emissions(𝒩)
        net = 𝒩[2]

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Check that there is production
        @test all(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯)

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::EmissionsEnergy)
        @test all(
            value.(m[:emissions_node][net, t, CO2]) ≈
            sum(value.(m[:flow_in][net, t, p]) * co2_int(p) for p ∈ inputs(net)) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
        @test all(value.(m[:emissions_node][net, t, NG]) ≈ 0 for t ∈ 𝒯, atol = TEST_ATOL)
    end

    @testset "Emissions tests - with energy and process emissions" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered

        # Run the model and extract the data
        em_data = EmissionsProcess(Dict(CO2 => 0.1, NG => 0.5))
        m, case, model = simple_graph(data_em = em_data)
        𝒩 = get_nodes(case)
        𝒩ᵉᵐ = nodes_emissions(𝒩)
        net = 𝒩[2]

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        𝒫   = get_products(case)
        𝒫ᵉᵐ = setdiff(filter(EMB.is_resource_emit, 𝒫), [CO2])

        # Check that there is production
        @test all(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯)

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::EmissionsProcess)
        @test all(
            value.(m[:emissions_node][net, t, CO2]) ≈
            sum(value.(m[:flow_in][net, t, p]) * co2_int(p) for p ∈ inputs(net)) +
            value.(m[:cap_use][net, t]) * process_emissions(em_data, CO2, t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
        @test all(
            value.(m[:emissions_node][net, t, NG]) ≈
            value.(m[:cap_use][net, t]) * process_emissions(em_data, NG, t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
    end

    @testset "Emissions tests - with energy and process emissions as TimeProfile" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered

        # Run the model and extract the data
        em_data = EmissionsProcess(Dict(CO2 => FixedProfile(0.1), NG => FixedProfile(0.5)))
        m, case, model = simple_graph(data_em = em_data)
        𝒩 = get_nodes(case)
        𝒩ᵉᵐ = nodes_emissions(𝒩)
        net = 𝒩[2]

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        𝒫   = get_products(case)
        𝒫ᵉᵐ = setdiff(filter(EMB.is_resource_emit, 𝒫), [CO2])

        # Check that there is production
        @test all(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯)

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::EmissionsProcess)
        @test all(
            value.(m[:emissions_node][net, t, CO2]) ≈
            sum(value.(m[:flow_in][net, t, p]) * co2_int(p) for p ∈ inputs(net)) +
            value.(m[:cap_use][net, t]) * process_emissions(em_data, CO2, t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
        @test all(
            value.(m[:emissions_node][net, t, NG]) ≈
            value.(m[:cap_use][net, t]) * process_emissions(em_data, NG, t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
    end

    @testset "Emissions tests - with capture on energy emissions" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered and the energy emissions are captured

        # Run the model and extract the data
        em_data = CaptureEnergyEmissions(Dict(CO2 => 0.1, NG => 0.5), 0.9)
        m, case, model = simple_graph(data_em = em_data)
        𝒩 = get_nodes(case)
        𝒩ᵉᵐ = nodes_emissions(𝒩)
        net = 𝒩[2]

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        𝒫   = get_products(case)
        𝒫ᵉᵐ = setdiff(filter(EMB.is_resource_emit, 𝒫), [CO2])

        # Check that there is production
        @test all(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯)

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::CaptureEnergyEmissions)
        @test all(
            value.(m[:emissions_node][net, t, CO2]) ≈
            sum(value.(m[:flow_in][net, t, p]) * co2_int(p) for p ∈ inputs(net)) *
            (1 - co2_capture(em_data)) +
            value.(m[:cap_use][net, t]) * process_emissions(em_data, CO2, t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
        @test all(
            value.(m[:emissions_node][net, t, NG]) ≈
            value.(m[:cap_use][net, t]) * process_emissions(em_data, NG, t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the CO2 capture is calculated correctly
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::CaptureEnergyEmissions)
        @test all(
            value.(m[:flow_out][net, t, CO2]) ≈
            sum(value.(m[:flow_in][net, t, p]) * co2_int(p) for p ∈ inputs(net)) *
            co2_capture(em_data) for t ∈ 𝒯, atol = TEST_ATOL
        )
    end

    @testset "Emissions tests - with capture on process emissions" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered and the process emissions are captured

        # Run the model and extract the data
        em_data = CaptureProcessEmissions(Dict(CO2 => 0.1, NG => 0.5), 0.9)
        m, case, model = simple_graph(data_em = em_data)
        𝒩 = get_nodes(case)
        𝒩ᵉᵐ = nodes_emissions(𝒩)
        net = 𝒩[2]

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        𝒫   = get_products(case)
        𝒫ᵉᵐ = setdiff(filter(EMB.is_resource_emit, 𝒫), [CO2])

        # Check that there is production
        @test all(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯)

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::CaptureEnergyEmissions)
        @test all(
            value.(m[:emissions_node][net, t, CO2]) ≈
            sum(value.(m[:flow_in][net, t, p]) * co2_int(p) for p ∈ inputs(net)) +
            value.(m[:cap_use][net, t]) *
            process_emissions(em_data, CO2, t) *
            (1 - co2_capture(em_data)) for t ∈ 𝒯, atol = TEST_ATOL
        )
        @test all(
            value.(m[:emissions_node][net, t, NG]) ≈
            value.(m[:cap_use][net, t]) * process_emissions(em_data, NG, t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the CO2 capture is calculated correctly
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::CaptureEnergyEmissions)
        @test all(
            value.(m[:flow_out][net, t, CO2]) ≈
            value.(m[:cap_use][net, t]) *
            process_emissions(em_data, CO2, t) *
            co2_capture(em_data) for t ∈ 𝒯, atol = TEST_ATOL
        )
    end

    @testset "Emissions tests - with capture on process emissions" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered and both emissions are captured

        # Run the model and extract the data
        em_data = CaptureProcessEnergyEmissions(Dict(CO2 => 0.1, NG => 0.5), 0.9)
        m, case, model = simple_graph(data_em = em_data)
        𝒩 = get_nodes(case)
        𝒩ᵉᵐ = nodes_emissions(𝒩)
        net = 𝒩[2]

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        𝒫   = get_products(case)
        𝒫ᵉᵐ = setdiff(filter(EMB.is_resource_emit, 𝒫), [CO2])

        # Check that there is production
        @test all(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯)

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::CaptureEnergyEmissions)
        @test all(
            value.(m[:emissions_node][net, t, CO2]) ≈
            (
                sum(value.(m[:flow_in][net, t, p]) * co2_int(p) for p ∈ inputs(net)) +
                value.(m[:cap_use][net, t]) * process_emissions(em_data, CO2, t)
            ) * (1 - co2_capture(em_data)) for t ∈ 𝒯, atol = TEST_ATOL
        )
        @test all(
            value.(m[:emissions_node][net, t, NG]) ≈
            value.(m[:cap_use][net, t]) * process_emissions(em_data, NG, t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the CO2 capture is calculated correctly
        # - constraints_ext_data(m, n::Node, 𝒯, 𝒫, modeltype::EnergyModel, data::CaptureEnergyEmissions)
        @test all(
            value.(m[:flow_out][net, t, CO2]) ≈
            (
                sum(value.(m[:flow_in][net, t, p]) * co2_int(p) for p ∈ inputs(net)) +
                value.(m[:cap_use][net, t]) * process_emissions(em_data, CO2, t)
            ) * co2_capture(em_data) for t ∈ 𝒯, atol = TEST_ATOL
        )
    end
end

@testset "Test RefStorage{CyclicStrategic}" begin
    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    aux = ResourceCarrier("aux", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(;
        ops = SimpleTimes(5, 2),
        op_per_strat = 10,
        demand = FixedProfile(10),
    )

        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(10),
            FixedProfile(10),
            FixedProfile(0),
            Dict(Power => 1),
        )
        aux_source = RefSource(
            "aux",
            FixedProfile(10),
            FixedProfile(10),
            FixedProfile(0),
            Dict(aux => 1),
        )
        storage = RefStorage{CyclicStrategic}(
            "storage",
            StorCapOpexVar(FixedProfile(10), FixedProfile(10)),
            StorCapOpexFixed(FixedProfile(1e8), FixedProfile(2)),
            Power,
            Dict(Power => 1, aux => 0.05),
            Dict(Power => 1),
        )

        sink = RefSink(
            "sink",
            demand,
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(1000)),
            Dict(Power => 1),
        )

        T = TwoLevel(2, 2, ops; op_per_strat)

        nodes = [source, aux_source, storage, sink]
        links = [
            Direct(13, source, storage)
            Direct(23, aux_source, storage)
            Direct(34, storage, sink)
        ]
        resources = [Power, aux, CO2]

        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # General tests function
    function general_tests(m, case, model)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]
        sink = 𝒩[4]

        # Test that the capacity is correctly limited
        # - constraints_capacity(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level][stor, t]) - value.(m[:stor_level_inst][stor, t]) ≤
            TEST_ATOL for t ∈ 𝒯
        )
        @test all(
            value.(m[:stor_charge_use][stor, t]) - value.(m[:stor_charge_inst][stor, t]) ≤
            TEST_ATOL for t ∈ 𝒯
        )

        # Test that the design for rate usage is correct
        # - constraints_flow_in(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:flow_in][stor, t, Power]) ≈ value.(m[:stor_charge_use][stor, t]) for
            t ∈ 𝒯, atol = TEST_ATOL
        )
        @test all(
            value.(m[:flow_in][stor, t, aux]) ≈
            value.(m[:stor_charge_use][stor, t]) * inputs(stor, aux) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the inlet flow is equivalent to the total usage of the demand
        @test sum(
            value.(m[:stor_charge_use][stor, t]) * duration(t) * multiple(t) for t ∈ 𝒯
        ) ≈ sum(value.(m[:cap_use][sink, t]) * duration(t) * multiple(t) for t ∈ 𝒯) atol =
            TEST_ATOL

        # Test that the total inlet flow is equivalent to the total outlet flow rate
        @test sum(
            value.(m[:flow_in][stor, t, Power]) * duration(t) * multiple(t) for t ∈ 𝒯
        ) ≈ sum(
            value.(m[:flow_out][stor, t, Power]) * duration(t) * multiple(t) for t ∈ 𝒯
        ) atol = TEST_ATOL

        # Test that the Δ in the storage level is correctly calculated
        # - constraints_level_aux(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level_Δ_op][stor, t]) ≈
            value.(m[:flow_in][stor, t, Power]) - value.(m[:flow_out][stor, t, Power]) for
            t ∈ 𝒯, atol = TEST_ATOL
        )
    end

    @testset "SimpleTimes without storage" begin

        # Run the model and extract the data
        m, case, model = simple_graph()
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # Test that we get the proper parameteric type
        @test typeof(stor) <: RefStorage{CyclicStrategic}

        # Test that the capacity is correctly limited
        # - constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level_inst][stor, t]) ≈ capacity(EMB.level(stor), t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
        @test all(
            value.(m[:stor_charge_inst][stor, t]) ≈ capacity(EMB.charge(stor), t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the input flow is equal to the output flow in the standard scenario as
        # storage does not pay off
        # - constraints_level_aux(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)
        @test all(value.(m[:stor_level_Δ_op][stor, t]) ≈ 0 for t ∈ 𝒯, atol = TEST_ATOL)

        # Test that the fixed OPEX is correctly calculated
        # - constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_fixed][stor, t_inv]) ≈
            EMB.opex_fixed(EMB.level(stor), t_inv) *
            value.(m[:stor_level_inst][stor, first(t_inv)]) for t_inv ∈ 𝒯ᴵⁿᵛ,
            atol = TEST_ATOL
        )

        # Test that variable OPEX is correctly calculated
        # - constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][stor, t_inv]) ≈ sum(
                EMB.opex_var(EMB.charge(stor), t_inv) *
                value.(m[:flow_in][stor, t, Power]) *
                duration(t) for t ∈ t_inv
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        )
    end

    @testset "SimpleTimes with storage" begin

        # Run the model and extract the data
        m, case, model = simple_graph(; demand = OperationalProfile([10, 15, 5, 15, 5]))
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # All the tests following are for the function, its individual methods, and the
        # called functions within the function.
        # constraints_level_iterate(
        #     m,
        #     n::Storage,
        #     prev_pers::PreviousPeriods,
        #     cyclic_pers::CyclicPeriods,
        #     per,
        #     _::,
        #     modeltype,
        # )
        # Test that the level balance is correct for standard periods (6 times)
        @test sum(
            sum(
                value.(m[:stor_level][stor, t]) ≈
                value.(m[:stor_level][stor, t_prev]) +
                value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
                (t_prev, t) ∈ withprev(t_inv) if !isnothing(t_prev)
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        ) ≈ length(𝒯) - 2 atol = TEST_ATOL

        # Test that the level balance is correct in the first period (2 times)
        @test sum(
            sum(
                value.(m[:stor_level][stor, t]) ≈
                value.(m[:stor_level][stor, last(t_inv)]) +
                value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
                (t_prev, t) ∈ withprev(t_inv) if isnothing(t_prev)
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        ) ≈ 2 atol = TEST_ATOL

        # Test that the level is 0 exactly 4 times
        @test sum(value.(m[:stor_level][stor, t]) ≈ 0 for t ∈ 𝒯, atol = TEST_ATOL) == 4
    end

    @testset "RepresentativePeriods with storage" begin

        # Run the model and extract the data
        op_profile_1 = FixedProfile(0)
        op_profile_2 = FixedProfile(20)
        demand = RepresentativeProfile([op_profile_1, op_profile_2])

        op_1 = SimpleTimes(10, 2)
        op_2 = SimpleTimes(40, 2)

        ops = RepresentativePeriods(2, 20, [0.5, 0.5], [op_1, op_2])

        m, case, model = simple_graph(; ops, op_per_strat = 8760, demand)

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # All the tests following are for the function, its individual methods, and the
        # called functions within the function.
        # constraints_level_iterate(
        #     m,
        #     n::Storage,
        #     prev_pers::PreviousPeriods,
        #     cyclic_pers::CyclicPeriods,
        #     per,
        #     _::,
        #     modeltype,
        # )
        for t_inv ∈ 𝒯ᴵⁿᵛ
            𝒯ʳᵖ = repr_periods(t_inv)
            for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
                if isnothing(t_rp_prev) && isnothing(t_prev)
                    # Test for the correct accounting in the first operational period of the
                    # first representative period of a strategic period
                    t_rp_last = last(𝒯ʳᵖ)
                    @test value.(m[:stor_level][stor, t]) ≈
                          value.(m[:stor_level][stor, first(t_rp_last)]) -
                          value.(m[:stor_level_Δ_op][stor, first(t_rp_last)]) *
                          duration(first(t_rp_last)) +
                          value.(m[:stor_level_Δ_rp][stor, t_rp_last]) +
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol =
                        TEST_ATOL

                    @test value.(m[:stor_level][stor, t]) -
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≥ -TEST_ATOL

                    @test value.(m[:stor_level][stor, t]) -
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≤
                          value.(m[:stor_level_inst][stor, t]) + TEST_ATOL

                elseif isnothing(t_prev)
                    # Test for the correct accounting in the first operational period of the
                    # other representative periods of a strategic period
                    @test value.(m[:stor_level][stor, t]) ≈
                          value.(m[:stor_level][stor, first(t_rp_prev)]) -
                          value.(m[:stor_level_Δ_op][stor, first(t_rp_prev)]) *
                          duration(first(t_rp_prev)) +
                          value.(m[:stor_level_Δ_rp][stor, t_rp_prev]) +
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol =
                        TEST_ATOL

                    @test value.(m[:stor_level][stor, t]) -
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≥ -TEST_ATOL

                    @test value.(m[:stor_level][stor, t]) -
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≤
                          value.(m[:stor_level_inst][stor, t]) + TEST_ATOL
                end
            end
        end
        # Test for the correct accounting in all other operational periods
        @test sum(
            value.(m[:stor_level][stor, t]) ≈
            value.(m[:stor_level][stor, t_prev]) +
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
            (t_prev, t) ∈ withprev(𝒯), atol = TEST_ATOL if !isnothing(t_prev)
        ) ≈ length(𝒯) - length(𝒯ᴵⁿᵛ) * ops.len atol = TEST_ATOL

        # Check that there is no outflow in the first representative period of each
        # strategic period as the demand is set to 0, and larger than 0 in the second
        # representative period
        @test sum(value.(m[:flow_out][stor, t, Power]) ≈ 0 for t ∈ 𝒯) ≈
              length(𝒯ᴵⁿᵛ) * length(op_1)
        @test sum(value.(m[:flow_out][stor, t, Power]) > 0 for t ∈ 𝒯) ≈
              length(𝒯ᴵⁿᵛ) * length(op_2)
    end
end

@testset "Test RefStorage{CyclicRepresentative}" begin
    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    aux = ResourceCarrier("aux", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(;
        ops = SimpleTimes(5, 2),
        op_per_strat = 10,
        demand = FixedProfile(10),
    )

        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(10),
            FixedProfile(10),
            FixedProfile(0),
            Dict(Power => 1),
        )
        aux_source = RefSource(
            "aux",
            FixedProfile(10),
            FixedProfile(10),
            FixedProfile(0),
            Dict(aux => 1),
        )
        storage = RefStorage{CyclicRepresentative}(
            "storage",
            StorCapOpexVar(FixedProfile(10), FixedProfile(10)),
            StorCapOpexFixed(FixedProfile(1e8), FixedProfile(2)),
            Power,
            Dict(Power => 1, aux => 0.05),
            Dict(Power => 1),
        )

        sink = RefSink(
            "sink",
            demand,
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(1000)),
            Dict(Power => 1),
        )

        T = TwoLevel(2, 2, ops; op_per_strat)

        nodes = [source, aux_source, storage, sink]
        links = [
            Direct(13, source, storage)
            Direct(23, aux_source, storage)
            Direct(34, storage, sink)
        ]
        resources = [Power, aux, CO2]

        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # General tests function
    function general_tests(m, case, model)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]
        sink = 𝒩[4]

        # Test that the capacity is correctly limited
        # - constraints_capacity(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level][stor, t]) - value.(m[:stor_level_inst][stor, t]) ≤
            TEST_ATOL for t ∈ 𝒯
        )
        @test all(
            value.(m[:stor_charge_use][stor, t]) - value.(m[:stor_charge_inst][stor, t]) ≤
            TEST_ATOL for t ∈ 𝒯
        )

        # Test that the design for rate usage is correct
        # - constraints_flow_in(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:flow_in][stor, t, Power]) ≈ value.(m[:stor_charge_use][stor, t]) for
            t ∈ 𝒯, atol = TEST_ATOL
        )
        @test all(
            value.(m[:flow_in][stor, t, aux]) ≈
            value.(m[:stor_charge_use][stor, t]) * inputs(stor, aux) for t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the inlet flow is equivalent to the total usage of the demand
        @test sum(
            value.(m[:stor_charge_use][stor, t]) * duration(t) * multiple(t) for t ∈ 𝒯
        ) ≈ sum(value.(m[:cap_use][sink, t]) * duration(t) * multiple(t) for t ∈ 𝒯) atol =
            TEST_ATOL

        # Test that the total inlet flow is equivalent to the total outlet flow rate
        # This test corresponds to
        @test sum(
            value.(m[:flow_in][stor, t, Power]) * duration(t) * multiple(t) for t ∈ 𝒯
        ) ≈ sum(
            value.(m[:flow_out][stor, t, Power]) * duration(t) * multiple(t) for t ∈ 𝒯
        ) atol = TEST_ATOL

        # Test that the Δ_op in the storage level is correctly calculated
        # - constraints_level_aux(m, n::RefStorage, 𝒯, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level_Δ_op][stor, t]) ≈
            value.(m[:flow_in][stor, t, Power]) - value.(m[:flow_out][stor, t, Power]) for
            t ∈ 𝒯, atol = TEST_ATOL
        )
    end

    @testset "SimpleTimes without storage" begin

        # Run the model and extract the data
        m, case, model = simple_graph()
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # Test that we get the proper parameteric type
        @test typeof(stor) <: EMB.Storage{CyclicRepresentative}

        # Test that the capacity is correctly limited
        # - constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level_inst][stor, t]) ≈ capacity(EMB.level(stor), t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
        @test all(
            value.(m[:stor_charge_inst][stor, t]) ≈ capacity(EMB.charge(stor), t) for
            t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the input flow is equal to the output flow in the standard scenario as
        # storage does not pay off
        # - constraints_level_aux(m, n::RefStorage{T}, 𝒯, 𝒫, modeltype::EnergyModel) where {T<:ResourceCarrier}
        @test all(value.(m[:stor_level_Δ_op][stor, t]) ≈ 0 for t ∈ 𝒯, atol = TEST_ATOL)

        # Test that the fixed OPEX is correctly calculated
        # - constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_fixed][stor, t_inv]) ≈
            EMB.opex_fixed(EMB.level(stor), t_inv) *
            value.(m[:stor_level_inst][stor, first(t_inv)]) for t_inv ∈ 𝒯ᴵⁿᵛ,
            atol = TEST_ATOL
        )

        # Test that variable OPEX is correctly calculated
        # - constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel
        @test all(
            value.(m[:opex_var][stor, t_inv]) ≈ sum(
                EMB.opex_var(EMB.charge(stor), t_inv) *
                value.(m[:flow_in][stor, t, Power]) *
                duration(t) for t ∈ t_inv
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        )
    end
    @testset "SimpleTimes with storage" begin

        # Run the model and extract the data
        m, case, model = simple_graph(; demand = OperationalProfile([10, 15, 5, 15, 5]))
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # All the tests following are for the function, its individual methods, and the
        # caleed functions within the function.
        # function constraints_level_iterate(
        #     m,
        #     n::Storage,
        #     prev_pers::PreviousPeriods,
        #     cyclic_pers::CyclicPeriods,
        #     per,
        #     _::,
        #     modeltype,
        # )

        # Test that the level balance is correct for standard periods (6 times)
        @test sum(
            sum(
                value.(m[:stor_level][stor, t]) ≈
                value.(m[:stor_level][stor, t_prev]) +
                value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
                (t_prev, t) ∈ withprev(t_inv) if !isnothing(t_prev)
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        ) ≈ length(𝒯) - 2 atol = TEST_ATOL

        # Test that the level balance is correct in the first period (2 times)
        @test sum(
            sum(
                value.(m[:stor_level][stor, t]) ≈
                value.(m[:stor_level][stor, last(t_inv)]) +
                value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
                (t_prev, t) ∈ withprev(t_inv) if isnothing(t_prev)
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        ) ≈ 2 atol = TEST_ATOL

        # Test that the level is 0 exactly 4 times
        @test sum(value.(m[:stor_level][stor, t]) ≈ 0 for t ∈ 𝒯, atol = TEST_ATOL) == 4
    end
    @testset "OperationalScenarios with storage" begin

        # Run the model and extract the data
        op_profile_1 = OperationalProfile([15, 5, 15, 5, 15, 5, 15, 5, 15, 5])
        op_profile_2 = OperationalProfile([20, 20, 0, 0, 20, 0, 20, 0, 20, 0])
        demand = ScenarioProfile([op_profile_1, op_profile_2])

        op_1 = SimpleTimes(10, 2)
        op_2 = SimpleTimes(10, 2)

        ops = OperationalScenarios(2, [op_1, op_2], [0.5, 0.5])

        m, case, model = simple_graph(; ops, op_per_strat = 20, demand)

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒯ˢᶜ = opscenarios(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # All the tests following are for the function, its individual methods, and the
        # caleed functions within the function.
        # function constraints_level_iterate(
        #     m,
        #     n::Storage,
        #     prev_pers::PreviousPeriods,
        #     cyclic_pers::CyclicPeriods,
        #     per,
        #     _::,
        #     modeltype,
        # )

        # Test that the level for starting an operational scenario is required to be the
        # same in the different operational scenarios
        first_scp = [first(t_scp) for t_scp ∈ 𝒯ˢᶜ]
        @test sum(
            value.(m[:stor_level][stor, t]) -
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≈ 40 for t ∈ first_scp,
            atol = TEST_ATOL
        ) ≈ length(first_scp) atol = TEST_ATOL

        for t_inv ∈ 𝒯ᴵⁿᵛ
            𝒯ʳᵖ = repr_periods(t_inv)
            for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
                if isnothing(t_prev)
                    # Test for the linking between the first and the last operational period
                    @test value.(m[:stor_level][stor, t]) ≈
                          value.(m[:stor_level][stor, last(t_rp)]) +
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol =
                        TEST_ATOL
                end
            end
        end
        # Test for the correct accounting in all other operational periods
        @test sum(
            value.(m[:stor_level][stor, t]) ≈
            value.(m[:stor_level][stor, t_prev]) +
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
            (t_prev, t) ∈ withprev(𝒯), atol = TEST_ATOL if !isnothing(t_prev)
        ) ≈ length(𝒯) - length(𝒯ᴵⁿᵛ) * ops.len atol = TEST_ATOL

        # Check that the level is 0 exactly 2 times
        @test sum(value.(m[:stor_level][stor, t]) ≈ 0 for t ∈ 𝒯) ≈ 2 atol = TEST_ATOL
    end
    @testset "RepresentativePeriods with storage" begin

        # Run the model and extract the data
        op_profile_1 = OperationalProfile([15, 5, 15, 5, 15, 5, 15, 5, 15, 5])
        op_profile_2 = OperationalProfile([20, 20, 0, 0, 20, 0, 20, 0, 20, 0])
        demand = RepresentativeProfile([op_profile_1, op_profile_2])

        op_1 = SimpleTimes(10, 2)
        op_2 = SimpleTimes(10, 2)

        ops = RepresentativePeriods(2, 8760, [0.5, 0.5], [op_1, op_2])

        m, case, model = simple_graph(; ops, op_per_strat = 8760, demand)

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒯ʳᵖ = repr_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # Test that the Δ_rp in the storage level is correctly fixed to 0
        # - constraints_level_rp(m, n::Storage, per, modeltype::EnergyModel)
        @test sum(
            value.(value.(m[:stor_level_Δ_rp][stor, t_rp])) ≈ 0 for t_rp ∈ 𝒯ʳᵖ,
            atol = TEST_ATOL
        ) ≈ length(𝒯ʳᵖ) atol = TEST_ATOL

        # All the tests following are for the function, its individual methods, and the
        # caleed functions within the function.
        # function constraints_level_iterate(
        #     m,
        #     n::Storage,
        #     prev_pers::PreviousPeriods,
        #     cyclic_pers::CyclicPeriods,
        #     per,
        #     _::,
        #     modeltype,
        # )

        # Test that the level for starting a representative period is not required to be the
        # same in the different representative periods
        first_rp = [first(t_rp) for t_rp ∈ 𝒯ʳᵖ]
        @test sum(
            value.(m[:stor_level][stor, t]) -
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≈ 10 for t ∈ first_rp,
            atol = TEST_ATOL
        ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:stor_level][stor, t]) -
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≈ 40 for t ∈ first_rp,
            atol = TEST_ATOL
        ) == length(𝒯ᴵⁿᵛ)

        for t_inv ∈ 𝒯ᴵⁿᵛ
            𝒯ʳᵖ = repr_periods(t_inv)
            for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
                if isnothing(t_prev)
                    # Test for the linking between the first and the last operational period
                    @test value.(m[:stor_level][stor, t]) ≈
                          value.(m[:stor_level][stor, last(t_rp)]) +
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol =
                        TEST_ATOL
                end
            end
        end
        # Test for the correct accounting in all other operational periods
        @test sum(
            value.(m[:stor_level][stor, t]) ≈
            value.(m[:stor_level][stor, t_prev]) +
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
            (t_prev, t) ∈ withprev(𝒯), atol = TEST_ATOL if !isnothing(t_prev)
        ) ≈ length(𝒯) - length(𝒯ᴵⁿᵛ) * ops.len atol = TEST_ATOL
    end
    @testset "OperationalScenarios and RepresentativePeriods with storage" begin

        # Run the model and extract the data
        op_profile_11 = OperationalProfile([15, 5, 15, 5, 10])
        op_profile_12 = OperationalProfile([20, 20, 0, 0, 10])
        op_profile_21 = OperationalProfile([5, 15, 5, 15, 10])
        op_profile_22 = OperationalProfile([0, 20, 0, 20, 10])
        scen_profile_1 = ScenarioProfile([op_profile_11, op_profile_12])
        scen_profile_2 = ScenarioProfile([op_profile_21, op_profile_22])
        demand = RepresentativeProfile([scen_profile_1, scen_profile_2])

        op = SimpleTimes(5, 2)
        scps = OperationalScenarios(2, [op, op], [0.5, 0.5])
        ops = RepresentativePeriods(2, 8760, [0.5, 0.5], [scps, scps])

        m, case, model = simple_graph(; ops, op_per_strat = 8760, demand)

        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒯ʳᵖ = repr_periods(𝒯)
        𝒯ˢᶜ = opscenarios(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]
        # Run the general tests
        general_tests(m, case, model)

        # All the tests following are for the function, its individual methods, and the
        # caleed functions within the function.
        # function constraints_level_iterate(
        #     m,
        #     n::Storage,
        #     prev_pers::PreviousPeriods,
        #     cyclic_pers::CyclicPeriods,
        #     per,
        #     _::,
        #     modeltype,
        # )

        # Test that the level for starting an operational scenario is required to be the
        # same in the different operational scenarios
        for t_rp ∈ 𝒯ʳᵖ
            first_scp = [first(t_scp) for t_scp ∈ opscenarios(t_rp)]
            @test value.(m[:stor_level][stor, first_scp[1]]) -
                  value.(m[:stor_level_Δ_op][stor, first_scp[1]]) * duration(first_scp[1]) ≈
                  value.(m[:stor_level][stor, first_scp[2]]) -
                  value.(m[:stor_level_Δ_op][stor, first_scp[2]]) * duration(first_scp[2])
            atol = TEST_ATOL
        end

        # Test that the level for starting a representative period is not required to be the
        # same in the different representative periods
        first_rp = [first(t_rp) for t_rp ∈ 𝒯ʳᵖ]
        @test sum(
            value.(m[:stor_level][stor, t]) -
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≈ 0
            for t ∈ first_rp, atol = TEST_ATOL
        ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:stor_level][stor, t]) -
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≈ 40 for t ∈ first_rp,
            atol = TEST_ATOL
        ) == length(𝒯ᴵⁿᵛ)

        for t_inv ∈ 𝒯ᴵⁿᵛ
            𝒯ʳᵖ = repr_periods(t_inv)
            for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
                if isnothing(t_prev)
                    # Test for the linking between the first and the last operational period
                    @test value.(m[:stor_level][stor, t]) ≈
                          value.(m[:stor_level][stor, last(t_rp)]) +
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol =
                        TEST_ATOL
                end
            end
        end
        # Test for the correct accounting in all other operational periods
        @test sum(
            value.(m[:stor_level][stor, t]) ≈
            value.(m[:stor_level][stor, t_prev]) +
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
            (t_prev, t) ∈ withprev(𝒯), atol = TEST_ATOL if !isnothing(t_prev)
        ) ≈ length(𝒯) - length(𝒯ᴵⁿᵛ) * ops.len * scps.len atol = TEST_ATOL

        # Check that the level is 0 exactly 14 times
        @test sum(value.(m[:stor_level][stor, t]) ≈ 0 for t ∈ 𝒯, atol = TEST_ATOL) ≈ 14
                atol = TEST_ATOL
    end
end

@testset "Test RefStorage{AccumulatingEmissions}" begin
    # Resources used in the analysis
    NG = ResourceEmit("NG", 0.2)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(;
        ops = SimpleTimes(5, 2),
        op_per_strat = 10,
        em_limit = [40, 40],
        stor_cap = 0,
    )
        em_data = CaptureEnergyEmissions(0.9)

        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(20),
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
            Dict(Power => 1, CO2 => 0),
            [em_data],
        )
        storage = RefStorage{AccumulatingEmissions}(
            "storage",
            StorCapOpex(FixedProfile(10), FixedProfile(1), FixedProfile(10)),
            StorCap(FixedProfile(stor_cap)),
            CO2,
            Dict(CO2 => 1),
            Dict(CO2 => 1),
        )

        sink = RefSink(
            "sink",
            FixedProfile(10),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(10000)),
            Dict(Power => 1),
        )

        T = TwoLevel(2, 2, ops; op_per_strat)

        nodes = [source, network, storage, sink]
        links = [
            Direct(12, source, network)
            Direct(24, network, sink)
            Direct(23, network, storage)
        ]
        resources = [NG, Power, CO2]

        model = OperationalModel(
            Dict(CO2 => StrategicProfile(em_limit), NG => FixedProfile(0)),
            Dict(CO2 => FixedProfile(0), NG => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # General tests function
    function general_tests(m, case, model)

        # Extract the data
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Test that there is production
        @test all(value.(m[:cap_use][𝒩[2], t]) > 0 for t ∈ 𝒯, atol = TEST_ATOL)

        # Test that the capacity is correctly limited
        # - constraints_capacity(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level][stor, t]) <= value.(m[:stor_level_inst][stor, t]) for
            t ∈ 𝒯, atol = TEST_ATOL
        )
        @test all(
            value.(m[:stor_charge_use][stor, t]) <= value.(m[:stor_charge_inst][stor, t])
            for t ∈ 𝒯, atol = TEST_ATOL
        )

        # Test that the design for rate usage is correct
        # - constraints_flow_in(m, n::Storage{AccumulatingEmissions}, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:flow_in][stor, t, CO2]) ≈
            value.(m[:stor_charge_use][stor, t]) + value.(m[:emissions_node][stor, t, CO2])
            for t ∈ 𝒯, atol = TEST_ATOL
        )

        # Test that the Δ in the storage level is correctly calculated
        # - constraints_level_aux(m, n::RefStorage{AccumulatingEmissions}, 𝒯, 𝒫, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level_Δ_op][stor, t]) ≈
            value.(m[:flow_in][stor, t, CO2]) - value.(m[:emissions_node][stor, t, CO2])
            for
            t ∈ 𝒯, atol = TEST_ATOL
        )

        # Test that the Δ in the storage level is larger than 0
        # - constraints_level_aux(m, n::RefStorage{AccumulatingEmissions}, 𝒯, 𝒫, modeltype::EnergyModel)
        @test all(value.(m[:stor_level_Δ_op][stor, t]) ≥ -TEST_ATOL for t ∈ 𝒯)
    end

    @testset "SimpleTimes without storage" begin
        # This test set is related to the approach of emissions in the storage node.
        # In practice, a RefStorage{AccumulatingEmissions} is also designed to act as an emission source
        # This is currently not well implemented, but will be adjusted in a later stage,

        # Run the model and extract the data
        m, case, model = simple_graph()
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # Test that we get the proper parameteric type
        @test typeof(stor) <: RefStorage{AccumulatingEmissions}

        # Test that the capacity is correctly limited
        # - constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_level_inst][stor, t]) ≈ capacity(EMB.level(stor), t) for t ∈ 𝒯,
            atol = TEST_ATOL
        )
        @test all(
            value.(m[:stor_charge_inst][stor, t]) ≈ capacity(EMB.charge(stor), t) for
            t ∈ 𝒯,
            atol = TEST_ATOL
        )

        # Test that the input flow is equal to the emissions as the limit allows it
        # - constraints_level_aux(m, n::RefStorage{AccumulatingEmissions}, 𝒯, 𝒫, modeltype::EnergyModel)
        @test all(
            value.(m[:flow_in][stor, t, CO2]) ≈ value.(m[:emissions_node][stor, t, CO2])
            for
            t ∈ 𝒯, atol = TEST_ATOL
        )

        # Test that the fixed OPEX is correctly calculated
        # - constraints_opex_fixed(m, n::Storage{AccumulatingEmissions}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_fixed][stor, t_inv]) ≈
            EMB.opex_fixed(EMB.charge(stor), t_inv) *
            value.(m[:stor_charge_inst][stor, first(t_inv)]) for t_inv ∈ 𝒯ᴵⁿᵛ,
            atol = TEST_ATOL
        )

        # Test that variable OPEX is correctly calculated
        # - constraints_opex_var(m, n::Storage{AccumulatingEmissions}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][stor, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        )
    end

    @testset "SimpleTimes with storage" begin

        # Run the model and extract the data
        m, case, model = simple_graph(; stor_cap = 100, em_limit = [100, 4])
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # Test that variable OPEX is correctly calculated
        # - function constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test all(
            value.(m[:opex_var][stor, t_inv]) ≈ sum(
                EMB.opex_var(EMB.charge(stor), t_inv) *
                (
                    value.(m[:flow_in][stor, t, CO2]) -
                    value.(m[:emissions_node][stor, t, CO2])
                ) *
                duration(t) for t ∈ t_inv
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        )

        # All the tests following are for the function, its individual methods, and the
        # called functions within the function.
        # constraints_level_iterate(
        #     m,
        #     n::Storage,
        #     prev_pers::PreviousPeriods,
        #     cyclic_pers::CyclicPeriods,
        #     per,
        #     _::,
        #     modeltype,
        # )
        # Test that the level balance is correct for standard periods (6 times)
        @test all(
            all(
                value.(m[:stor_level][stor, t]) ≈
                value.(m[:stor_level][stor, t_prev]) +
                (
                    value.(m[:flow_in][stor, t, CO2]) -
                    value.(m[:emissions_node][stor, t, CO2])
                ) * duration(t) for (t_prev, t) ∈ withprev(t_inv) if !isnothing(t_prev)
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        )

        # Test that the level balance is correct in the first period (2 times)
        @test all(
            all(
                value.(m[:stor_level][stor, t]) ≈
                (
                    value.(m[:flow_in][stor, t, CO2]) -
                    value.(m[:emissions_node][stor, t, CO2])
                ) * duration(t) for (t_prev, t) ∈ withprev(t_inv) if isnothing(t_prev)
            ) for t_inv ∈ 𝒯ᴵⁿᵛ, atol = TEST_ATOL
        )
    end

    @testset "RepresentativePeriods with storage" begin

        # Run the model and extract the data
        op_1 = SimpleTimes(2, 2)
        op_2 = SimpleTimes(2, 2)
        ops = RepresentativePeriods(2, 60, [0.5, 0.5], [op_1, op_2])

        m, case, model = simple_graph(; ops, op_per_strat = 60, stor_cap = 1e6)
        𝒯 = get_time_struct(case)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩 = get_nodes(case)
        stor = 𝒩[3]

        # Run the general tests
        general_tests(m, case, model)

        # All the tests following are for the function, its individual methods, and the
        # called functions within the function.
        # constraints_level_iterate(
        #     m,
        #     n::Storage,
        #     prev_pers::PreviousPeriods,
        #     cyclic_pers::CyclicPeriods,
        #     per,
        #     _::,
        #     modeltype,
        # )
        for t_inv ∈ 𝒯ᴵⁿᵛ
            𝒯ʳᵖ = repr_periods(t_inv)
            for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
                if isnothing(t_rp_prev) && isnothing(t_prev)
                    # Test for the correct accounting in the first operational period of the
                    # first representative period of a strategic period

                    @test value.(m[:stor_level][stor, t]) ≈
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol =
                        TEST_ATOL

                elseif isnothing(t_prev)
                    # Test for the correct accounting in the first operational period of the
                    # other representative periods of a strategic period
                    Δlevel_rp = sum(
                        value.(m[:stor_level_Δ_op][stor, t]) *
                        multiple_strat(t_inv, t) *
                        duration(t) for t ∈ t_rp_prev
                    )
                    @test value.(m[:stor_level][stor, t]) ≈
                          value.(m[:stor_level][stor, first(t_rp_prev)]) -
                          value.(m[:stor_level_Δ_op][stor, first(t_rp_prev)]) *
                          duration(first(t_rp_prev)) +
                          value.(m[:stor_level_Δ_rp][stor, t_rp_prev]) +
                          value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol =
                        TEST_ATOL
                end
            end
        end
        # Test for the correct accounting in all other operational periods
        @test sum(
            value.(m[:stor_level][stor, t]) ≈
            value.(m[:stor_level][stor, t_prev]) +
            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) for
            (t_prev, t) ∈ withprev(𝒯), atol = TEST_ATOL if !isnothing(t_prev)
        ) ≈ length(𝒯) - length(𝒯ᴵⁿᵛ) * ops.len atol = TEST_ATOL
    end
end

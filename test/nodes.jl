
@testset "Test RefSource and RefSink" begin

    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(source::Source, sink::Sink)

        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat=duration(ops))

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

    @testset "Checks :surplus/:deficit" begin
        # Source used in the analysis
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(Power => 1),
            [],
        )

        # Test that an inconsistent Sink.Penalty dict is caught by the checks.
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :def => FixedProfile(2)),
            Dict(Power => 1),
            [],
        )
        @test_throws AssertionError simple_graph(source, sink)

        # The penalties in this Sink node lead to an infeasible optimum. Test that the
        # checks forbids it.
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(-4), :deficit => FixedProfile(2)),
            Dict(Power => 1),
            [],
        )
        @test_throws AssertionError simple_graph(source, sink)

        # The penalties in this Sink node are valid, and should lead to an optimal solution.
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(-4), :deficit => FixedProfile(4)),
            Dict(Power => 1),
            [],
        )
        m, case, model = simple_graph(source, sink)
        @test termination_status(m) == MOI.OPTIMAL
    end

    @testset "General tests - RefSink" begin


        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(2),
            FixedProfile(10),
            Dict(Power => 1.5),
            []
        )
        sink = RefSink(
            "sink",
            OperationalProfile([6, 8, 10, 6, 8]),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
            Dict(Power => 1),
            [],
        )

        m, case, model = simple_graph(source, sink)
        𝒯       = case[:T]
        𝒯ᴵⁿᵛ    = strategic_periods(𝒯)

        # Test that the capacity bound is properly set
        # - constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:cap_inst][source, t]) ≈ EMB.capacity(source)[t]
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the capacity bound is properly utilized for a `RefSink`
        # - constraints_capacity(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:cap_use][source, t]) <= value.(m[:cap_inst][source, t])
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the outflow is equal to the specified capacity usage
        # - constraints_flow_out(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:flow_out][source, t, Power]) ≈
                value.(m[:cap_use][source, t]) * EMB.output(source, Power)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL


        # Test that the variable OPEX values are properly calculated for RefSource
        # - constraints_opex_var(m, n::Node, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_var][source, t_inv]) ≈
                sum(value.(m[:cap_use][source, t]) * EMB.opex_var(source, t) * duration(t)
                for t ∈ t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                    length(𝒯ᴵⁿᵛ) atol=TEST_ATOL

        # Test that the fixed OPEX values are properly calculated for RefSource
        # - constraints_opex_fixed(m, n::Node, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_fixed][source, t_inv]) ≈
                 EMB.opex_fixed(source, t_inv) * value.(m[:cap_inst][source, first(t_inv)])
                 for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                    length(𝒯ᴵⁿᵛ) atol=TEST_ATOL
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
            []
        )
        sink = RefSink(
            "sink",
            FixedProfile(8),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
            Dict(Power => 1),
            [],
        )

        m, case, model = simple_graph(source, sink)
        𝒯       = case[:T]
        𝒯ᴵⁿᵛ    = strategic_periods(𝒯)

        # Test that the inflow is equal to the specified capacity usage
        # - constraints_flow_in(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:flow_in][sink, t, Power]) ≈
                value.(m[:cap_use][sink, t]) * EMB.input(sink, Power)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the mass balance is properly calculated
        # - constraints_capacity(m, n::Sink, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:sink_deficit][sink, t] for t ∈ 𝒯)) ≈
                length(𝒯)*4 atol=TEST_ATOL
        @test sum(value.(m[:sink_deficit][sink, t]) + value.(m[:cap_use][sink, t]) ≈
                value.(m[:sink_surplus][sink, t]) + value.(m[:cap_inst][sink, t])
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the fixed OPEX is set to 0
        # - constraints_opex_fixed(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_fixed][sink, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) ≈
                length(𝒯ᴵⁿᵛ) atol=TEST_ATOL

        # Test that the opex calculations are correct
        # - constraints_opex_var(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_var][sink, t_inv]) ≈
                sum(value.(m[:sink_deficit][sink, t]) * duration(t) * EMB.deficit(sink, t) for t ∈ t_inv)
                for t_inv ∈ 𝒯ᴵⁿᵛ)  ≈
                    length(𝒯ᴵⁿᵛ) atol=TEST_ATOL

        # Test that the surplus values are properly calculated and time is involved
        # in the penalty calculation
        sink = RefSink(2,
                        FixedProfile(2),
                        Dict(:surplus => FixedProfile(-100), :deficit => FixedProfile(100)),
                        Dict(Power => 1),
                        [],
        )
        m, case, model = simple_graph(source, sink)
        𝒯       = case[:T]
        𝒯ᴵⁿᵛ    = strategic_periods(𝒯)

        # Test that the mass balance is properly calculated
        # - constraints_capacity(m, n::Sink, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:sink_surplus][sink, t]) for t ∈ 𝒯) ≈
                length(𝒯)*2 atol=TEST_ATOL
        @test sum(value.(m[:sink_deficit][sink, t]) + value.(m[:cap_use][sink, t]) ≈
                value.(m[:sink_surplus][sink, t]) + value.(m[:cap_inst][sink, t])
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the opex calculations are correct
        # - constraints_opex_var(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_var][sink, t_inv]) ≈
                sum(value.(m[:sink_surplus][sink, t]) * duration(t) * EMB.surplus(sink, t) for t ∈ t_inv)
                for t_inv ∈ 𝒯ᴵⁿᵛ) ==
                    length(𝒯ᴵⁿᵛ)

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
            []
        )
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
            [],
        )
        m, case, model = simple_graph(source, sink)
        𝒯       = case[:T]
        @test !any(val == source for val ∈ axes(m[:emissions_node])[1])
        @test !any(val == sink for val ∈ axes(m[:emissions_node])[1])

        # Test that the emissions from a sink node with emissions are properly accounted for
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsProcess)
        em_data = EmissionsProcess(Dict(CO2 => 10))
        snk_emit = RefSink(
            "sink_emit",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
            [em_data],
        )
        m, case, model = simple_graph(source, snk_emit)
        𝒯       = case[:T]
        # Test that the emissions are properly calculated
        @test sum(value.(m[:cap_use][snk_emit, t]) * EMB.process_emissions(em_data, CO2) ≈
                value.(m[:emissions_node][snk_emit, t, CO2]) for t ∈ 𝒯) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the emissions from a source node with emissions are properly accounted for
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsProcess)
        em_data = EmissionsProcess(Dict(CO2 => 10))
        src_emit = RefSource(
            "source_emit",
            FixedProfile(4),
            FixedProfile(0),
            FixedProfile(10),
            Dict(Power => 1),
            [em_data],
        )
        m, case, model = simple_graph(src_emit, sink)
        𝒯       = case[:T]
        # Test that the emissions are properly calculated, although no input is present in
        # a `Source ndoe`
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsProcess)
        @test sum(value.(m[:cap_use][src_emit, t]) * EMB.process_emissions(em_data, CO2) ≈
                value.(m[:emissions_node][src_emit, t, CO2]) for t ∈ 𝒯) ≈
                    length(𝒯) atol=TEST_ATOL
    end
end

@testset "Test RefNetworkNode with various emission variables" begin
    # Resources used in the analysis
    NG = ResourceEmit("NG", 0.2)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(;data_em=nothing)

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
            data_net = []
            data_source = []
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
            data_net
        )

        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
            [],
        )

        resources = [NG, Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat=duration(ops))

        nodes = [source, network, sink]
        links = [
            Direct(12, source, network)
            Direct(23, network, sink)
            ]

        if typeof(data_em) <: EMB.CaptureData
            CO2_stor = RefSink(
                "CO2 sink",
                FixedProfile(0),
                Dict(
                    :surplus => FixedProfile(9.1),
                    :deficit => FixedProfile(20),
                ),
                Dict(CO2 => 1, Power => 0.02),
                []
            )
            push!(nodes, CO2_stor)
            append!(links, [Direct(14, source, CO2_stor),  Direct(24, network, CO2_stor)])
        end


        model = OperationalModel(Dict(CO2 => FixedProfile(100), NG => FixedProfile(100)), CO2)
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    @testset "Emissions tests - wo Emissions" begin
        # Check that the overall emission balance is working and that the emissions
        # variables are only created if required.

        # Run the model and extract the data
        m, case, model = simple_graph()
        𝒯       = case[:T]
        𝒯ᴵⁿᵛ    = strategic_periods(𝒯)
        𝒩     = case[:nodes]
        net   = 𝒩[2]

        # Check that there is production
        @test sum(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯) ≈ length(𝒯) atol=TEST_ATOL

        # Check that no emission variables are created without emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 0

        # Check that the total and strategic emissions are 0
        # - constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test sum(value.(m[:emissions_strategic][t_inv, CO2]) ≈ 0
                for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                    length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:emissions_total][t, CO2]) ≈ 0
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯)
        @test sum(value.(m[:emissions_strategic][t_inv, NG]) ≈ 0
                for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                    length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:emissions_total][t, NG]) ≈ 0
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯)
    end

    @testset "Emissions tests - with energy emissions" begin
        # Check that the emissions are properly calculated when only energy emissions are
        # considered

        # Run the model and extract the data
        em_data = EmissionsEnergy()
        m, case, model = simple_graph(data_em=em_data)
        𝒩     = case[:nodes]
        𝒩ᵉᵐ   = EMB.node_emissions(𝒩)
        net   = 𝒩[2]

        𝒯     = case[:T]
        𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

        # Check that there is production
        @test sum(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯) ≈ length(𝒯) atol=TEST_ATOL

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsEnergy)
        @test sum(value.(m[:emissions_node][net, t, CO2]) ≈
                sum(value.(m[:flow_in][net, t, p]) * EMB.co2_int(p) for p ∈ EMB.input(net))
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯)
        @test sum(value.(m[:emissions_node][net, t, NG]) ≈ 0
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯)
    end

    @testset "Emissions tests - with energy and process emissions" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered

        # Run the model and extract the data
        em_data = EmissionsProcess(Dict(CO2 => 0.1, NG => 0.5))
        m, case, model = simple_graph(data_em=em_data)
        𝒩     = case[:nodes]
        𝒩ᵉᵐ   = EMB.node_emissions(𝒩)
        net   = 𝒩[2]

        𝒯     = case[:T]
        𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

        𝒫   = case[:products]
        𝒫ᵉᵐ = EMB.res_not(EMB.res_em(𝒫), CO2)

        # Check that there is production
        @test sum(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯) ≈ length(𝒯) atol=TEST_ATOL

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsProcess)
        @test sum(value.(m[:emissions_node][net, t, CO2]) ≈
                sum(value.(m[:flow_in][net, t, p]) * EMB.co2_int(p) for p ∈ EMB.input(net)) +
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, CO2)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯)
        @test sum(value.(m[:emissions_node][net, t, NG]) ≈
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, NG)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯)
    end

    @testset "Emissions tests - with capture on energy emissions" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered and the energy emissions are captured

        # Run the model and extract the data
        em_data = CaptureEnergyEmissions(Dict(CO2 => 0.1, NG => 0.5), 0.9)
        m, case, model = simple_graph(data_em=em_data)
        𝒩     = case[:nodes]
        𝒩ᵉᵐ   = EMB.node_emissions(𝒩)
        net   = 𝒩[2]

        𝒯     = case[:T]
        𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

        𝒫   = case[:products]
        𝒫ᵉᵐ = EMB.res_not(EMB.res_em(𝒫), CO2)

        # Check that there is production
        @test sum(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯) ≈ length(𝒯) atol=TEST_ATOL

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureEnergyEmissions)
        @test sum(value.(m[:emissions_node][net, t, CO2]) ≈
                sum(value.(m[:flow_in][net, t, p]) * EMB.co2_int(p) for p ∈ EMB.input(net)) *
                (1 - EMB.co2_capture(em_data)) +
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, CO2)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL
        @test sum(value.(m[:emissions_node][net, t, NG]) ≈
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, NG)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the CO2 capture is calculated correctly
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureEnergyEmissions)
        @test sum(value.(m[:flow_out][net, t, CO2]) ≈
                sum(value.(m[:flow_in][net, t, p]) * EMB.co2_int(p) for p ∈ EMB.input(net)) *
                EMB.co2_capture(em_data) for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL
    end

    @testset "Emissions tests - with capture on process emissions" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered and the process emissions are captured

        # Run the model and extract the data
        em_data = CaptureProcessEmissions(Dict(CO2 => 0.1, NG => 0.5), 0.9)
        m, case, model = simple_graph(data_em=em_data)
        𝒩     = case[:nodes]
        𝒩ᵉᵐ   = EMB.node_emissions(𝒩)
        net   = 𝒩[2]

        𝒯     = case[:T]
        𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

        𝒫   = case[:products]
        𝒫ᵉᵐ = EMB.res_not(EMB.res_em(𝒫), CO2)

        # Check that there is production
        @test sum(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯) ≈ length(𝒯) atol=TEST_ATOL

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureEnergyEmissions)
        @test sum(value.(m[:emissions_node][net, t, CO2]) ≈
                sum(value.(m[:flow_in][net, t, p]) * EMB.co2_int(p) for p ∈ EMB.input(net)) +
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, CO2) *
                (1 - EMB.co2_capture(em_data))
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL
        @test sum(value.(m[:emissions_node][net, t, NG]) ≈
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, NG)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the CO2 capture is calculated correctly
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureEnergyEmissions)
        @test sum(value.(m[:flow_out][net, t, CO2]) ≈
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, CO2) *
                EMB.co2_capture(em_data) for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL
    end

    @testset "Emissions tests - with capture on process emissions" begin
        # Check that the emissions are properly calculated when both energy and process
        # emissions are considered and both emissions are captured

        # Run the model and extract the data
        em_data = CaptureProcessEnergyEmissions(Dict(CO2 => 0.1, NG => 0.5), 0.9)
        m, case, model = simple_graph(data_em=em_data)
        𝒩     = case[:nodes]
        𝒩ᵉᵐ   = EMB.node_emissions(𝒩)
        net   = 𝒩[2]

        𝒯     = case[:T]
        𝒯ᴵⁿᵛ  = strategic_periods(𝒯)

        𝒫   = case[:products]
        𝒫ᵉᵐ = EMB.res_not(EMB.res_em(𝒫), CO2)

        # Check that there is production
        @test sum(value.(m[:cap_use][net, t]) > 0 for t ∈ 𝒯) ≈ length(𝒯) atol=TEST_ATOL

        # Check that the # of created variables correspond to the # of nodes with emissions
        # - variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test size(m[:emissions_node])[1] == 2

        # Check that the total and strategic emissions are correctly calculated
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureEnergyEmissions)
        @test sum(value.(m[:emissions_node][net, t, CO2]) ≈
                (sum(value.(m[:flow_in][net, t, p]) * EMB.co2_int(p) for p ∈ EMB.input(net)) +
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, CO2)) *
                (1 - EMB.co2_capture(em_data))
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL
        @test sum(value.(m[:emissions_node][net, t, NG]) ≈
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, NG)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the CO2 capture is calculated correctly
        # - constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureEnergyEmissions)
        @test sum(value.(m[:flow_out][net, t, CO2]) ≈
                (sum(value.(m[:flow_in][net, t, p]) * EMB.co2_int(p) for p ∈ EMB.input(net)) +
                value.(m[:cap_use][net, t]) * EMB.process_emissions(em_data, CO2)) *
                EMB.co2_capture(em_data) for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL
    end
end

@testset "Test RefStorage{<:ResourceCarrier}" begin
    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    aux = ResourceCarrier("aux", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(;ops=SimpleTimes(5, 2), demand=FixedProfile(10))


        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(10),
            FixedProfile(10),
            FixedProfile(0),
            Dict(Power => 1),
            [],
        )
        aux_source = RefSource(
            "aux",
            FixedProfile(10),
            FixedProfile(10),
            FixedProfile(0),
            Dict(aux => 1),
            [],
        )
        storage = RefStorage(
            "storage",
            FixedProfile(10),
            FixedProfile(1e8),
            FixedProfile(10),
            FixedProfile(2),
            Power,
            Dict(Power => 1, aux => 0.05),
            Dict(Power => 1),
            Array{Data}([])
        )

        sink = RefSink(
            "sink",
            demand,
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(1000)),
            Dict(Power => 1),
            [],
        )

        T = TwoLevel(2, 2, ops; op_per_strat=duration(ops))

        nodes = [source, aux_source, storage, sink]
        links = [
            Direct(13, source, storage)
            Direct(23, aux_source, storage)
            Direct(34, storage, sink)
            ]
        resources = [Power, aux, CO2]

        model = OperationalModel(Dict(CO2 => FixedProfile(100)), CO2)
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # General tests function
    function general_tests(m, case, model)

        # Extract the data
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩    = case[:nodes]
        stor = 𝒩[3]
        sink = 𝒩[4]

        # Test that the capacity is correctly limited
        # - constraints_capacity(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:stor_level][stor, t]) - value.(m[:stor_cap_inst][stor, t])
                     ≤ TEST_ATOL for t ∈ 𝒯) ≈
                        length(𝒯) atol=TEST_ATOL
        @test sum(value.(m[:stor_rate_use][stor, t]) - value.(m[:stor_rate_inst][stor, t])
                     ≤ TEST_ATOL for t ∈ 𝒯) ≈
                        length(𝒯) atol=TEST_ATOL

        # Test that the design for rate usage is correct
        # - constraints_flow_in(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:flow_in][stor, t, Power]) ≈ value.(m[:stor_rate_use][stor, t])
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL
        @test sum(value.(m[:flow_in][stor, t, aux]) ≈
                    value.(m[:stor_rate_use][stor, t]) * EMB.input(stor, aux)
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL

        # Test that the inlet flow is equivalent to the total usage of the demand
        @test sum(value.(m[:stor_rate_use][stor, t]) * duration(t) * multiple(t) for t ∈ 𝒯) ≈
                sum(value.(m[:cap_use][sink,t]) * duration(t) * multiple(t)  for t ∈ 𝒯) atol=TEST_ATOL

        # Test that the total inlet flow is equivalent to the total outlet flow rate
        # This test corresponds to
        @test sum(value.(m[:flow_in][stor, t, Power]) * duration(t) * multiple(t)  for t ∈ 𝒯) ≈
                sum(value.(m[:flow_out][stor, t, Power]) * duration(t) * multiple(t)  for t ∈ 𝒯)  atol=TEST_ATOL


        # Test that the Δ in the storage level is correctly calculated
        # - constraints_level_aux(m, n::RefStorage{T}, 𝒯) where {S<:ResourceCarrier}
        @test sum(value.(value.(m[:stor_level_Δ_op][stor, t])) ≈
                value.(m[:flow_in][stor, t, Power]) - value.(m[:flow_out][stor, t, Power])
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL

    end

    @testset "SimpleTimes without storage" begin

        # Run the model and extract the data
        m, case, model = simple_graph()
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩    = case[:nodes]
        stor = 𝒩[3]
        cap = EMB.capacity(stor)

        # Run the general tests
        general_tests(m, case, model);

        # Test that we get the proper parameteric type
        @test typeof(stor) <: RefStorage{<:ResourceCarrier}

        # Test that the capacity is correctly limited
        # - constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:stor_cap_inst][stor, t]) ≈ cap.level[t]
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL
        @test sum(value.(m[:stor_rate_inst][stor, t]) ≈ cap.rate[t]
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL

        # Test that the input flow is equal to the output flow in the standard scenario as
        # storage does not pay off
        # - constraints_level_aux(m, n::RefStorage{S}, 𝒯, 𝒫) where {S<:ResourceCarrier}
        @test sum(value.(m[:stor_level_Δ_op][stor, t]) ≈ 0 for t ∈ 𝒯, atol=TEST_ATOL) ≈
                length(𝒯) atol=TEST_ATOL

        # Test that the fixed OPEX is correctly calculated
        # - constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_fixed][stor, t_inv]) ≈
                EMB.opex_fixed(stor, t_inv) * value.(m[:stor_cap_inst][stor, first(t_inv)])
                    for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                length(𝒯ᴵⁿᵛ) atol=TEST_ATOL

        # Test that variable OPEX is correctly calculated
        # - constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_var][stor, t_inv]) ≈
                sum(EMB.opex_var(stor, t_inv) * value.(m[:flow_in][stor, t, Power]) *
                    duration(t) for t ∈ t_inv)
                for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                length(𝒯ᴵⁿᵛ) atol=TEST_ATOL
    end

    @testset "SimpleTimes with storage" begin

        # Run the model and extract the data
        m, case, model = simple_graph(demand=OperationalProfile([10, 15, 5, 15, 5]))
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩    = case[:nodes]
        stor = 𝒩[3]
        cap = EMB.capacity(stor)

        # Run the general tests
        general_tests(m, case, model);

        # All the tests following er for the function
        # - constraints_level(m, n::RefStorage{T}, 𝒯, 𝒫, modeltype::EnergyModel) where {T<:ResourceCarrier}

        # Test that the level balance is correct for standard periods (6 times)
        @test sum(sum(value.(m[:stor_level][stor, t]) ≈
                    value.(m[:stor_level][stor, t_prev]) +
                    value.(m[:stor_level_Δ_op][stor, t]) * duration(t)
                    for (t_prev, t) ∈ withprev(t_inv) if !isnothing(t_prev))
                    for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                        length(𝒯)-2 atol=TEST_ATOL

        # Test that the level balance is correct in the first period (2 times)
        @test sum(sum(value.(m[:stor_level][stor, t]) ≈
                    value.(m[:stor_level][stor, last(t_inv)]) +
                    value.(m[:stor_level_Δ_op][stor, t]) * duration(t)
                    for (t_prev, t) ∈ withprev(t_inv) if isnothing(t_prev))
                    for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                        2 atol=TEST_ATOL

        # Test that the level is 0 exactly 4 times
        @test sum(value.(m[:stor_level][stor, t]) ≈ 0 for t ∈ 𝒯, atol=TEST_ATOL) == 4
    end

    @testset "RepresentativePeriods with storage" begin

        # Run the model and extract the data
        op_profile_1 = FixedProfile(0)
        op_profile_2 = OperationalProfile([20, 20, 20, 20, 20])
        demand = RepresentativeProfile([op_profile_1, op_profile_2])

        op_1 = SimpleTimes(100, 2)
        op_2 = SimpleTimes(800, 2)

        ops = RepresentativePeriods(2, 8760, [.5, .5], [op_1, op_2])

        m, case, model = simple_graph(ops=ops, demand=demand)

        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩    = case[:nodes]
        stor = 𝒩[3]
        cap = EMB.capacity(stor)

        # Run the general tests
        general_tests(m, case, model);

        # All the tests following er for the function
        # - constraints_level(m, n::RefStorage{T}, 𝒯, 𝒫, modeltype::EnergyModel) where {T<:ResourceCarrier}
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
                            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol=TEST_ATOL

                    @test value.(m[:stor_level][stor, t]) -
                            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≥
                            -TEST_ATOL

                    @test value.(m[:stor_level][stor, t]) -
                            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≤
                            value.(m[:stor_cap_inst][stor, t]) + TEST_ATOL

                elseif isnothing(t_prev)
                    # Test for the correct accounting in the first operational period of the
                    # other representative periods of a strategic period
                    @test value.(m[:stor_level][stor, t]) ≈
                            value.(m[:stor_level][stor, first(t_rp_prev)]) -
                            value.(m[:stor_level_Δ_op][stor, first(t_rp_prev)]) *
                                duration(first(t_rp_prev)) +
                            value.(m[:stor_level_Δ_rp][stor, t_rp_prev]) +
                            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol=TEST_ATOL

                    @test value.(m[:stor_level][stor, t]) -
                            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≥
                            -TEST_ATOL

                    @test value.(m[:stor_level][stor, t]) -
                            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) ≤
                            value.(m[:stor_cap_inst][stor, t]) + TEST_ATOL
                end
            end
        end
        # Test for the correct accounting in all other operational periods
        @test sum(value.(m[:stor_level][stor, t]) ≈
                value.(m[:stor_level][stor, t_prev]) +
                value.(m[:stor_level_Δ_op][stor, t]) * duration(t)
                for (t_prev, t) ∈ withprev(𝒯), atol= TEST_ATOL if !isnothing(t_prev)) ≈
                    length(𝒯) - length(𝒯ᴵⁿᵛ) * ops.len atol= TEST_ATOL

        # Check that there is no outflow in the first representative period of each
        # strategic period as the demand is set to 0, and larger than 0 in the second
        # representative period
        @test sum(value.(m[:flow_out][stor, t, Power]) ≈ 0 for t ∈ 𝒯) ≈
            length(𝒯ᴵⁿᵛ)*length(op_1)
        @test sum(value.(m[:flow_out][stor, t, Power]) > 0 for t ∈ 𝒯) ≈
            length(𝒯ᴵⁿᵛ)*length(op_2)
    end
end

@testset "Test RefStorage{<:ResourceEmit}" begin
    # Resources used in the analysis
    NG = ResourceEmit("NG", 0.2)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)


    # Function for setting up the system
    function simple_graph(;ops=SimpleTimes(5, 2) , em_limit=[40, 40], stor_cap=0)

        em_data = CaptureEnergyEmissions(0.9)

        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(20),
            FixedProfile(10),
            FixedProfile(0),
            Dict(NG => 1),
            Array{Data}([])
        )
        network = RefNetworkNode(
            "network",
            FixedProfile(25),
            FixedProfile(5.5),
            FixedProfile(0),
            Dict(NG => 2),
            Dict(Power => 1, CO2 => 0),
            [em_data]
        )
        storage = RefStorage(
            "storage",
            FixedProfile(10),
            FixedProfile(stor_cap),
            FixedProfile(1),
            FixedProfile(10),
            CO2,
            Dict(CO2 => 1),
            Dict(CO2 => 1),
            Array{Data}([])
        )

        sink = RefSink(
            "sink",
            FixedProfile(10),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(10000)),
            Dict(Power => 1),
            [],
        )

        T = TwoLevel(2, 2, ops; op_per_strat=duration(ops))

        nodes = [source, network, storage, sink]
        links = [
            Direct(12, source, network)
            Direct(24, network, sink)
            Direct(23, network, storage)
            ]
        resources = [NG, Power, CO2]

        model = OperationalModel(Dict(CO2 => StrategicProfile(em_limit), NG => FixedProfile(0)), CO2)
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # General tests function
    function general_tests(m, case, model)

        # Extract the data
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩    = case[:nodes]
        stor = 𝒩[3]

        # Test that there is production
        @test sum(value.(m[:cap_use][𝒩[2], t]) > 0 for t ∈ 𝒯, atol=TEST_ATOL) ≈
            length(𝒯) atol=TEST_ATOL

        # Test that the capacity is correctly limited
        # - constraints_capacity(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:stor_level][stor, t]) <= value.(m[:stor_cap_inst][stor, t])
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL
        @test sum(value.(m[:stor_rate_use][stor, t]) <= value.(m[:stor_rate_inst][stor, t])
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL

        # Test that the design for rate usage is correct
        # - constraints_flow_in(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:flow_in][stor, t, CO2]) ≈ value.(m[:stor_rate_use][stor, t])
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL

        # Test that the Δ in the storage level is correctly calculated
        # - constraints_level_aux(m, n::RefStorage{T}, 𝒯) where {S<:ResourceEmit}
        @test sum(value.(value.(m[:stor_level_Δ_op][stor, t])) ≈
                value.(m[:flow_in][stor, t, CO2]) - value.(m[:emissions_node][stor, t, CO2])
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL

        # Test that the Δ in the storage level is larger than 0
        # - constraints_level_aux(m, n::RefStorage{T}, 𝒯) where {S<:ResourceEmit}
        @test sum(value.(value.(m[:stor_level_Δ_op][stor, t])) ≥ -TEST_ATOL
                for t ∈ 𝒯) ≈
                    length(𝒯) atol=TEST_ATOL

    end

    @testset "SimpleTimes without storage" begin
        # This test set is related to the approach of emissions in the storage node.
        # In practice, a RefStorage{<:ResourceEmit} is also designed to act as an emission source
        # This is currently not well implemented, but will be adjusted in a later stage

        # Run the model and extract the data
        m, case, model = simple_graph()
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩    = case[:nodes]
        stor = 𝒩[3]
        cap = EMB.capacity(stor)

        # Run the general tests
        general_tests(m, case, model);

        # Test that we get the proper parameteric type
        @test typeof(stor) <: RefStorage{<:ResourceEmit}

        # Test that the capacity is correctly limited
        # - constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test sum(value.(m[:stor_cap_inst][stor, t]) ≈ cap.level[t]
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL
        @test sum(value.(m[:stor_rate_inst][stor, t]) ≈ cap.rate[t]
                    for t ∈ 𝒯, atol=TEST_ATOL) ≈
                        length(𝒯) atol=TEST_ATOL

        # Test that the input flow is equal to the emissions as the limit allows it
        # - constraints_level(m, n::RefStorage{T}, 𝒯, 𝒫, modeltype::EnergyModel) where {T<:ResourceEmit}
        @test sum(value.(m[:flow_in][stor, t, CO2]) ≈ value.(m[:emissions_node][stor, t, CO2])
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯) atol=TEST_ATOL

        # Test that the fixed OPEX is correctly calculated
        # - function constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_fixed][stor, t_inv]) ≈
                EMB.opex_fixed(stor, t_inv) * value.(m[:stor_rate_inst][stor, first(t_inv)])
                    for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                length(𝒯ᴵⁿᵛ) atol=TEST_ATOL

        # Test that variable OPEX is correctly calculated
        # - function constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_var][stor, t_inv]) ≈ 0
                for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                length(𝒯ᴵⁿᵛ) atol=TEST_ATOL
    end

    @testset "SimpleTimes with storage" begin

        # Run the model and extract the data
        m, case, model = simple_graph(stor_cap=100, em_limit=[100, 4])
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩    = case[:nodes]
        stor = 𝒩[3]
        cap = EMB.capacity(stor)

        # Run the general tests
        general_tests(m, case, model);

        # Test that variable OPEX is correctly calculated
        # - function constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
        @test sum(value.(m[:opex_var][stor, t_inv]) ≈
                sum(EMB.opex_var(stor, t_inv) *
                (value.(m[:flow_in][stor, t, CO2]) -
                 value.(m[:emissions_node][stor, t, CO2])) *
                duration(t) for t ∈ t_inv)
                for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                length(𝒯ᴵⁿᵛ) atol=TEST_ATOL

        # All the tests following er for the function
        # - constraints_level(m, n::RefStorage{T}, 𝒯, 𝒫, modeltype::EnergyModel) where {T<:ResourceEmit}

        # Test that the level balance is correct for standard periods (6 times)
        @test sum(sum(value.(m[:stor_level][stor, t]) ≈
                    value.(m[:stor_level][stor, t_prev]) +
                        (value.(m[:flow_in][stor, t , CO2]) -
                         value.(m[:emissions_node][stor, t , CO2])) *
                    duration(t)
                    for (t_prev, t) ∈ withprev(t_inv) if !isnothing(t_prev))
                    for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                        length(𝒯)-2 atol=TEST_ATOL

        # Test that the level balance is correct in the first period (2 times)
        @test sum(sum(value.(m[:stor_level][stor, t]) ≈
                        (value.(m[:flow_in][stor, t , CO2]) -
                         value.(m[:emissions_node][stor, t , CO2])) *
                    duration(t)
                    for (t_prev, t) ∈ withprev(t_inv) if isnothing(t_prev))
                    for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                        2 atol=TEST_ATOL
    end

    @testset "RepresentativePeriods with storage" begin

        # Run the model and extract the data
        op_1 = SimpleTimes(5, 2)
        op_2 = SimpleTimes(10, 2)
        ops = RepresentativePeriods(2, 60, [.5, .5], [op_1, op_2])

        m, case, model = simple_graph(ops=ops, stor_cap=1e6)
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        𝒩    = case[:nodes]
        stor = 𝒩[3]
        cap = EMB.capacity(stor)

        # Run the general tests
        general_tests(m, case, model);

        # All the tests following er for the function
        # - constraints_level(m, n::RefStorage{T}, 𝒯, 𝒫, modeltype::EnergyModel) where {T<:ResourceEmit}
        for t_inv ∈ 𝒯ᴵⁿᵛ
            𝒯ʳᵖ = repr_periods(t_inv)
            for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
                if isnothing(t_rp_prev) && isnothing(t_prev)
                    # Test for the correct accounting in the first operational period of the
                    # first representative period of a strategic period

                    @test value.(m[:stor_level][stor, t]) ≈
                            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol=TEST_ATOL

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
                            value.(m[:stor_level_Δ_op][stor, t]) * duration(t) atol=TEST_ATOL
                end
            end
        end
        # Test for the correct accounting in all other operational periods
        @test sum(value.(m[:stor_level][stor, t]) ≈
                value.(m[:stor_level][stor, t_prev]) +
                value.(m[:stor_level_Δ_op][stor, t]) * duration(t)
                for (t_prev, t) ∈ withprev(𝒯), atol= TEST_ATOL if !isnothing(t_prev)) ≈
                    length(𝒯) - length(𝒯ᴵⁿᵛ) * ops.len atol= TEST_ATOL
    end
end

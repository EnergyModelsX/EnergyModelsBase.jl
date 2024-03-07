# Set the global to true to suppress the error message
EMB.TEST_ENV = true

@testset "Test checks - emission data" begin
    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(em_data::Vector{<:EmissionsData})

        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat=10)

        source = RefSource(
            "source_emit",
            FixedProfile(4),
            FixedProfile(0),
            FixedProfile(10),
            Dict(Power => 1),
            em_data,
        )
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(-4), :deficit => FixedProfile(4)),
            Dict(Power => 1),
        )

        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat=10)

        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2
        )
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return case, model
    end

    # Create a function for running the simple graph
    function run_simple_graph(em_data::Vector{<:EmissionsData})
        case, model = simple_graph(em_data)
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # Test that only a single EmissionData is allowed
    # - EMB.check_node_data(n::Node, data::EmissionsData, 𝒯, modeltype::EnergyModel)
    em_data = [EmissionsProcess(Dict(CO2 => 10.0)), EmissionsEnergy()]
    @test_throws AssertionError run_simple_graph(em_data)

    # Test that the capture rate is bound by 0 and 1
    # - EMB.check_node_data(n::Node, data::CaptureData, 𝒯, modeltype::EnergyModel)
    em_data = [CaptureEnergyEmissions(1.2)]
    @test_throws AssertionError run_simple_graph(em_data)
    em_data = [CaptureEnergyEmissions(-1.2)]
    @test_throws AssertionError run_simple_graph(em_data)

    # Test that the timeprofile check is working
    # - EMB.check_node_data(n::Node, data::EmissionsData, 𝒯, modeltype::EnergyModel
    em_data = [EmissionsProcess(Dict(CO2 => StrategicProfile([1])))]
    @test_throws AssertionError run_simple_graph(em_data)
    case, model = simple_graph(em_data)
    msg = "Checking of the time profiles is deactivated:\n" *
    "Deactivating the checks for the time profiles is strongly discouraged.\n" *
    "While the model will still run, unexpected results can occur, as well as\n" *
    "inconsistent case data.\n\n" *
    "Deactivating the checks for the timeprofiles should only be considered,\n" *
    "when testing new components. In all other instances, it is recommended to\n" *
    "provide the correct timeprofiles using a preprocessing routine. \n\n" *
    "If timeprofiles are not checked, inconsistencies can occur."
    @test_logs (:warn, msg) create_model(case, model; check_timeprofiles=false)

end

@testset "Test checks - timeprofiles" begin

    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(T::TimeStructure, tp::TimeProfile)

        resources = [Power, CO2]

        source = RefSource(
            "source_emit",
            tp,
            FixedProfile(0),
            FixedProfile(10),
            Dict(Power => 1),
        )
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(-4), :deficit => FixedProfile(4)),
            Dict(Power => 1),
        )

        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2
        )

        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2
        )
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return case, model
    end

    # Create a function for running the simple graph
    function run_simple_graph(T::TimeStructure, tp::TimeProfile)
        case, model = simple_graph(T, tp)
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    day = SimpleTimes(24, 1)

    # Test that there is an error with wrong strategic profiles
    # - EMB.check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevel)
    ts = TwoLevel(2, 1, day)
    ops = OperationalProfile(ones(24))
    tp = StrategicProfile([ops, ops, ops])
    @test_throws AssertionError run_simple_graph(ts, tp)

    # Test that there is an error with wrong operational profiles
    # - EMB.check_profile(fieldname, value::OperationalProfile, ts::SimpleTimes, sp)
    ts = TwoLevel(2, 1, day)
    tp = OperationalProfile(ones(20))
    @test_throws AssertionError run_simple_graph(ts, tp)
    tp = OperationalProfile(ones(30))
    @test_throws AssertionError run_simple_graph(ts, tp)

    # Test that there is warning when using OperationalProfile with RepresentativePeriods
    # - EMB.check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, sp)
    ts = TwoLevel(2, 1, RepresentativePeriods(3, 8760, ones(3)/3, [day, day, day]))
    tp = OperationalProfile(ones(24))
    msg = "Field cap: Using `OperionalProfile` with \
    `RepresentativePeriods` is dangerous, as it may lead to unexpected behaviour. \
    It only works reasonable if all representative periods have an operational \
    time structure of the same length. Otherwise, the last value is repeated. \
    The system is tested for the all representative periods."
    @test_logs (:warn, msg) run_simple_graph(ts, tp)

    # Test that there is warning when using RepresentativeProfile without RepresentativePeriods
    # - EMB.check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, sp)
    ts = TwoLevel(2, 1, day)
    tp = RepresentativeProfile([FixedProfile(5), FixedProfile(10)])
    msg = "Field cap: Using `RepresentativeProfile` with `SimpleTimes` is dangerous, as it \
    may lead to unexpected behaviour. In this case, only the first profile is used and tested."
    @test_logs (:warn, msg) run_simple_graph(ts, tp)

    # Test that there is an error when `RepresentativeProfile` have a different length than
    # the corresponding `RepresentativePeriods`
    # - EMB.check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, sp)
    ts = TwoLevel(2, 1, RepresentativePeriods(3, 8760, ones(3)/3, [day, day, day]))
    @test_throws AssertionError run_simple_graph(ts, tp)

    # Check that turning of the timeprofile checks leads to a warning
    case, model = simple_graph(ts, tp)
    msg = "Checking of the time profiles is deactivated:\n" *
    "Deactivating the checks for the time profiles is strongly discouraged.\n" *
    "While the model will still run, unexpected results can occur, as well as\n" *
    "inconsistent case data.\n\n" *
    "Deactivating the checks for the timeprofiles should only be considered,\n" *
    "when testing new components. In all other instances, it is recommended to\n" *
    "provide the correct timeprofiles using a preprocessing routine. \n\n" *
    "If timeprofiles are not checked, inconsistencies can occur."
    @test_logs (:warn, msg) create_model(case, model; check_timeprofiles=false)
end

@testset "Test checks - Nodes" begin

    # Resources used in the checks
    NG = ResourceEmit("NG", 0.2)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    aux = ResourceCarrier("aux", 0.0)

    # Function for setting up the system for testing `Sink` and `Source`
    function simple_graph(source::Source, sink::Sink)
        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat=10)

        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2
        )
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # Test that the fields of a Source are correctly checked
    # - check_node(n::Source, 𝒯, modeltype::EnergyModel)
    @testset "Checks Source" begin
        # Sink used in the analysis
        sink = RefSink(
            "sink",
            OperationalProfile([6, 8, 10, 6, 8]),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
            Dict(Power => 1),
        )

        # Test that a wrong capacity is caught by the checks.
        source = RefSource(
            "source",
            FixedProfile(-4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(source, sink)

        # Test that a wrong output dictionary is caught by the checks.
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(Power => -1),
        )
        @test_throws AssertionError simple_graph(source, sink)

        # Test that a wrong fixed OPEX is caught by the checks.
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(-5),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(source, sink)

        # Test that correct input solves the model to optimality.
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(5),
            Dict(Power => 1),
        )
        m , _, _ = simple_graph(source, sink)
        @test termination_status(m) == MOI.OPTIMAL
    end

    # Test that the fields of a Sink are correctly checked
    # - check_node(n::Sink, 𝒯, modeltype::EnergyModel)
    @testset "Checks Sink" begin
        # Source used in the analysis
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(Power => 1),
        )

        # Test that an inconsistent Sink.penalty dictionaries is caught by the checks.
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :def => FixedProfile(2)),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(source, sink)

        # The penalties in this Sink node lead to an infeasible optimum. Test that the
        # checks forbids it.
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(-4), :deficit => FixedProfile(2)),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(source, sink)

        # Check that a wrong capacity in a sink is caught by the checks.
        sink = RefSink(
            "sink",
            OperationalProfile(-[6, 8, 10, 6, 8]),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(source, sink)

        # Test that correct input solves the model to optimality.
        sink = RefSink(
            "sink",
            OperationalProfile([6, 8, 10, 6, 8]),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
            Dict(Power => 1),
        )
        m , _, _ = simple_graph(source, sink)
        @test termination_status(m) == MOI.OPTIMAL
    end

    # Function for setting up the system for testing a `NetworkNode`
    function simple_graph(network::NetworkNode)

        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(NG => 1),
        )

        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
        )

        resources = [NG, Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat=10)

        nodes = [source, network, sink]
        links = [
            Direct(12, source, network)
            Direct(23, network, sink)
            ]

        model = OperationalModel(
            Dict(CO2 => FixedProfile(100), NG => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0), NG => FixedProfile(0)),
            CO2
        )
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # Test that the fields of a NetworkNode are correctly checked
    # - check_node(n::NetworkNode, 𝒯, modeltype::EnergyModel)
    @testset "Test checks - NetworkNode" begin

        # Test that a wrong capacity is caught by the checks.
        network = RefNetworkNode(
            "network",
            FixedProfile(-25),
            FixedProfile(5.5),
            FixedProfile(0),
            Dict(NG => 2),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(network)

        # Test that a wrong fixed OPEX is caught by the checks.
        network = RefNetworkNode(
            "network",
            FixedProfile(25),
            FixedProfile(5.5),
            FixedProfile(-100),
            Dict(NG => 2),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(network)

        # Test that a wrong input dictionary is caught by the checks.
        network = RefNetworkNode(
            "network",
            FixedProfile(25),
            FixedProfile(5.5),
            FixedProfile(0),
            Dict(NG => -2),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(network)

        # Test that a wrong output dictionary is caught by the checks.
        network = RefNetworkNode(
            "network",
            FixedProfile(25),
            FixedProfile(5.5),
            FixedProfile(0),
            Dict(NG => 2),
            Dict(Power => -1),
        )
        @test_throws AssertionError simple_graph(network)

        # Test that correct input solves the model to optimality.
        network = RefNetworkNode(
            "network",
            FixedProfile(25),
            FixedProfile(5.5),
            FixedProfile(0),
            Dict(NG => 2),
            Dict(Power => 1),
        )
        m , _, _ = simple_graph(network)
        @test termination_status(m) == MOI.OPTIMAL
    end


    # Function for setting up the system for testing a `Storage` node
    function simple_graph(storage::Storage)

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

        sink = RefSink(
            "sink",
            FixedProfile(10),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(1000)),
            Dict(Power => 1),
        )

        T = TwoLevel(2, 2, SimpleTimes(5, 2); op_per_strat=10)

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
            CO2
        )
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return run_model(case, model, HiGHS.Optimizer), case, model
    end

    # Test that the fields of a Storage are correctly checked
    # - check_node(n::Storage, 𝒯, modeltype::EnergyModel)
    @testset "Test checks - Storage" begin

        # Test that a wrong capacities are caught by the checks.
        storage = RefStorage(
            "storage",
            FixedProfile(-10),
            FixedProfile(1e8),
            FixedProfile(10),
            FixedProfile(2),
            Power,
            Dict(Power => 1, aux => 0.05),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(storage)
        storage = RefStorage(
            "storage",
            FixedProfile(10),
            FixedProfile(-1e8),
            FixedProfile(10),
            FixedProfile(2),
            Power,
            Dict(Power => 1, aux => 0.05),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(storage)


        # Test that a wrong fixed OPEX is caught by the checks.
        storage = RefStorage(
            "storage",
            FixedProfile(10),
            FixedProfile(1e8),
            FixedProfile(10),
            FixedProfile(-2),
            Power,
            Dict(Power => 1, aux => 0.05),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(storage)


        # Test that a wrong input dictionary is caught by the checks.
        storage = RefStorage(
            "storage",
            FixedProfile(10),
            FixedProfile(1e8),
            FixedProfile(10),
            FixedProfile(2),
            Power,
            Dict(Power => -1, aux => 0.05),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(storage)
        storage = RefStorage(
            "storage",
            FixedProfile(10),
            FixedProfile(1e8),
            FixedProfile(10),
            FixedProfile(2),
            Power,
            Dict(Power => 1, aux => -0.05),
            Dict(Power => 1),
        )
        @test_throws AssertionError simple_graph(storage)

        # Test that a wrong output dictionary is caught by the checks.
        storage = RefStorage(
            "storage",
            FixedProfile(10),
            FixedProfile(1e8),
            FixedProfile(10),
            FixedProfile(2),
            Power,
            Dict(Power => 1, aux => 0.05),
            Dict(Power => -1),
        )
        @test_throws AssertionError simple_graph(storage)

        # Test that correct input solves the model to optimality.
        storage = RefStorage(
            "storage",
            FixedProfile(10),
            FixedProfile(1e8),
            FixedProfile(10),
            FixedProfile(2),
            Power,
            Dict(Power => 1, aux => 0.05),
            Dict(Power => 1),
        )
        m , _, _ = simple_graph(storage)
        @test termination_status(m) == MOI.OPTIMAL
    end
end

# Set the global again to false
EMB.TEST_ENV = false

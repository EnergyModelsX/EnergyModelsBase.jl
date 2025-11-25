# Set the global to true to suppress the error message
EMB.TEST_ENV = true

@testset "Checks - case type" begin
    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Setting up the system
    resources = [Power, CO2]
    ops = SimpleTimes(5, 2)
    T = TwoLevel(2, 2, ops; op_per_strat = 10)

    source = RefSource(
        "source_emit",
        FixedProfile(4),
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

    ops = SimpleTimes(5, 2)
    T = TwoLevel(2, 2, ops; op_per_strat = 10)

    nodes = [source, sink]
    links = Link[Direct(12, source, sink)]
    model = OperationalModel(
        Dict(CO2 => FixedProfile(100)),
        Dict(CO2 => FixedProfile(0)),
        CO2,
    )

    # Check that the individual elements vector are unique
    # - EMB.check_case_data(case)
    case_test = Case(T, resources, [nodes, [nodes[1]], links])
    @test_throws AssertionError create_model(case_test, model)
    case_test = Case(T, resources, [nodes, [nodes[2]], links])
    @test_throws AssertionError create_model(case_test, model)
    case_test = Case(T, resources, [nodes, [links[1]], links])
    @test_throws AssertionError create_model(case_test, model)

    # Check that the couplings return non_empty vectors
    # - EMB.check_case_data(case)
    case_test = Case(T, resources, [nodes, Link[]], [[get_nodes, get_links]])
    @test_throws AssertionError create_model(case_test, model)
end

@testset "Checks - modeltype" begin
    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph()
        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat = 10)

        source = RefSource(
            "source_emit",
            FixedProfile(4),
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

        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat = 10)

        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return case
    end

    # Create a function for running the simple graph
    function create_simple_graph(;
        co2_limit::TS.TimeProfile = FixedProfile(100),
        co2_price::TS.TimeProfile = FixedProfile(0),
    )
        case = simple_graph()
        model = OperationalModel(Dict(CO2 => co2_limit), Dict(CO2 => co2_price), CO2)
        return create_model(case, model), case, model
    end

    # Extract the default values
    case = simple_graph()
    model =
        OperationalModel(Dict(CO2 => FixedProfile(100)), Dict(CO2 => FixedProfile(0)), CO2)

    # Check that all resources present in the case data are included in the emission limit
    # and emission price
    # - EMB.check_model(case, modeltype::EnergyModel, check_timeprofiles)
    case_test = deepcopy(case)
    ng = ResourceEmit("NG", 0.06)
    append!(case_test.products, [ng])
    model = OperationalModel(
        Dict(CO2 => FixedProfile(100)),
        Dict(CO2 => FixedProfile(0), ng => FixedProfile(10)),
        CO2,
    )
    @test_throws AssertionError create_model(case_test, model)

    # Check that the timeprofiles for emission limit and price are correct
    # - EMB.check_model(case, modeltype::EnergyModel, check_timeprofiles)
    model = OperationalModel(
        Dict(CO2 => StrategicProfile([100])),
        Dict(CO2 => FixedProfile(0)),
        CO2,
    )
    @test_throws AssertionError create_model(case, model)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(0)),
        Dict(CO2 => StrategicProfile([100])),
        CO2,
    )
    @test_throws AssertionError create_model(case, model)

    # Check that we receive an error if the profiles are wrong. For emission price, it is
    # only necessary to check that it provides an error for a single case.
    # - EMB.check_strategic_profile(time_profile, message)
    rprofile = RepresentativeProfile([FixedProfile(100)])
    scprofile = ScenarioProfile([FixedProfile(100)])
    oprofile = OperationalProfile(ones(100))

    co2_limit = oprofile
    @test_throws AssertionError create_simple_graph(;co2_limit)
    co2_limit = scprofile
    @test_throws AssertionError create_simple_graph(;co2_limit)
    co2_limit = rprofile
    @test_throws AssertionError create_simple_graph(;co2_limit)
    co2_limit = StrategicProfile([4])
    @test_throws AssertionError create_simple_graph(;co2_limit)

    co2_limit = StrategicProfile([oprofile, oprofile, oprofile, oprofile])
    @test_throws AssertionError create_simple_graph(;co2_limit)
    co2_limit = StrategicProfile([scprofile, scprofile, scprofile, scprofile])
    @test_throws AssertionError create_simple_graph(;co2_limit)
    co2_limit = StrategicProfile([rprofile, rprofile, rprofile, rprofile])
    @test_throws AssertionError create_simple_graph(;co2_limit)

    co2_price = oprofile
    @test_throws AssertionError create_simple_graph(;co2_price)
end

@testset "Checks - emission data" begin
    # Resources used in the analysis
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system
    function simple_graph(em_data::Vector{<:EmissionsData})
        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat = 10)

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
        T = TwoLevel(2, 2, ops; op_per_strat = 10)

        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return case, model
    end

    # Create a function for running the simple graph
    function run_simple_graph(em_data::Vector{<:EmissionsData})
        case, model = simple_graph(em_data)
        return create_model(case, model), case, model
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

    # Test that the timeprofile check is working and only showing the warning once
    # - EMB.check_node_data(n::Node, data::EmissionsData, 𝒯, modeltype::EnergyModel
    em_data = [EmissionsProcess(Dict(CO2 => StrategicProfile([1])))]
    @test_throws AssertionError run_simple_graph(em_data)
    case, model = simple_graph(em_data)
    msg =
        "Checking of the time profiles is deactivated:\n" *
        "Deactivating the checks for the time profiles is strongly discouraged. " *
        "While the model will still run, unexpected results can occur, as well as " *
        "inconsistent case data.\n\n" *
        "Deactivating the checks for the timeprofiles should only be considered, " *
        "when testing new components. In all other instances, it is recommended to " *
        "provide the correct timeprofiles using a preprocessing routine.\n\n" *
        "If timeprofiles are not checked, inconsistencies can occur."
    @test_logs (:warn, msg) create_model(case, model; check_timeprofiles = false)
    @test_logs (:warn, msg) for k ∈ [1, 2]
        create_model(case, model; check_timeprofiles = false)
    end
end

@testset "Checks - timeprofiles" begin

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

        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return case, model
    end

    # Create a function for running the simple graph
    function create_simple_graph(T::TimeStructure, tp::TimeProfile)
        case, model = simple_graph(T, tp)
        return create_model(case, model), case, model
    end

    day = SimpleTimes(24, 1)

    # Test that there is an error with wrong strategic profiles
    # - EMB.check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevel)
    ts = TwoLevel(2, 1, day)
    ops = OperationalProfile(ones(24))
    profiles = [
        StrategicProfile([ops, ops, ops]),
        StrategicProfile([ops]),
    ]
    for tp ∈ profiles
        @test_throws AssertionError create_simple_graph(ts, tp)
    end

    # Test that there is an error with wrong `OperationalProfile`s
    # - EMB.check_profile(fieldname, value::OperationalProfile, ts::SimpleTimes, sp)
    profiles = [
        OperationalProfile(ones(20)),
        OperationalProfile(ones(30)),
    ]
    for tp ∈ profiles
        @test_throws AssertionError create_simple_graph(ts, tp)
    end

    # Test that there is an error with wrong `OperationalProfile`s in operational scenarios
    # - EMB.check_profile(fieldname, value::OperationalProfile, ts::OperationalScenarios, sp)
    oscs = OperationalScenarios(3, day)
    ts =  TwoLevel(2, 1, oscs)
    for tp ∈ profiles
        @test_throws AssertionError create_simple_graph(ts, tp)
    end

    # Test that there is an error with wrong `OperationalProfile`s in representative periods
    # - EMB.check_profile(fieldname, value::OperationalProfile, ts::RepresentativePeriods, sp)
    ts =  TwoLevel(2, 1, RepresentativePeriods(2, [.5, .5], day))
    for tp ∈ profiles
        @test_throws AssertionError create_simple_graph(ts, tp)
    end

    # Test that there is an error with wrong `OperationalProfile`s in operational scenarios
    # in representative periods
    # - EMB.check_profile(fieldname, value::OperationalProfile, ts::OperationalScenarios, sp)
    # - EMB.check_profile(fieldname, value::OperationalProfile, ts::RepresentativePeriods, sp)
    ts =  TwoLevel(2, 1, RepresentativePeriods(2, [.5, .5], oscs))
    for tp ∈ profiles
        @test_throws AssertionError create_simple_graph(ts, tp)
    end

    # Test that there is warning when using `ScenarioProfile` without `OperationalScenarios`
    # - EMB.check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, sp)
    ts = TwoLevel(2, 1, day)
    ops = FixedProfile(5)
    profiles = [ScenarioProfile([ops, ops]), ScenarioProfile([ops, ops, ops, ops])]
    msg =
        "Using `ScenarioProfile` with `SimpleTimes` is dangerous, as it may " *
        "lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested."
    @test_logs (:warn, msg) create_simple_graph(ts, profiles[1]);

    # Test that there is an error with wrong `ScenarioProfile`s
    # - EMB.check_profile(fieldname, value::ScenarioProfile, ts::SimpleTimes, sp)
    ts =  TwoLevel(2, 1, oscs)
    for tp ∈ profiles
        @test_throws AssertionError create_simple_graph(ts, tp)
    end

    # Test that there is an error with wrong `OperationalProfile`s in representative periods
    # - EMB.check_profile(fieldname, value::OperationalProfile, ts::RepresentativePeriods, sp)
    ts =  TwoLevel(2, 1, RepresentativePeriods(2, [.5, .5], oscs))
    for tp ∈ profiles
        @test_throws AssertionError create_simple_graph(ts, tp)
    end

    # Test that there is warning when using `RepresentativeProfile` without
    # `RepresentativePeriods`
    # - EMB.check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, sp)
    ts = TwoLevel(2, 1, day)
    tp = RepresentativeProfile([ops, ops])
    msg =
        "Using `RepresentativeProfile` with `SimpleTimes` is dangerous, as it may " *
        "lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested."
    @test_logs (:warn, msg) create_simple_graph(ts, tp);
    # - EMB.check_profile(fieldname, value::RepresentativeProfile, ts::OperationalScenarios, sp)
    ts =  TwoLevel(2, 1, OperationalScenarios(2, day))
    msg =
        "Using `RepresentativeProfile` with `OperationalScenarios` is dangerous, as it may " *
        "lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested."
    @test_logs (:warn, msg) create_simple_graph(ts, tp);

    # Test that there is an error with wrong `RepresentativeProfile`s
    # - EMB.check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, sp)
    ts = TwoLevel(2, 1, RepresentativePeriods(2, ones(3) / 3, [day, day, day]))
    profiles = [
        RepresentativeProfile([ops, ops]),
        RepresentativeProfile([ops, ops, ops, ops]),
    ]
    for tp ∈ profiles
        @test_throws AssertionError create_simple_graph(ts, tp)
    end

    # Check that turning of the timeprofile checks leads to a warning
    case, model = simple_graph(ts, tp)
    msg =
        "Checking of the time profiles is deactivated:\n" *
        "Deactivating the checks for the time profiles is strongly discouraged. " *
        "While the model will still run, unexpected results can occur, as well as " *
        "inconsistent case data.\n\n" *
        "Deactivating the checks for the timeprofiles should only be considered, " *
        "when testing new components. In all other instances, it is recommended to " *
        "provide the correct timeprofiles using a preprocessing routine.\n\n" *
        "If timeprofiles are not checked, inconsistencies can occur."
    @test_logs (:warn, msg) create_model(case, model; check_timeprofiles = false)

    # Deactivate logging and instead use `assert_or_log` as `assert`
    EMB.ASSERTS_AS_LOG = false

    # Check that wrong profiles for strategic indexable variables are identified
    # - EMB.check_strategic_profile(time_profile::TimeProfile, message::String)
    profiles = [
        OperationalProfile([5]),
        ScenarioProfile([5]),
        RepresentativeProfile([5]),
        StrategicProfile([OperationalProfile([5])]),
        StrategicProfile([ScenarioProfile([5])]),
        StrategicProfile([RepresentativeProfile([5])]),
    ]
    for tp ∈ profiles
        @test_throws AssertionError EMB.check_strategic_profile(tp, "")
    end

    # Check that wrong profiles for representative indexable variables are identified
    # - EMB.check_representative_profile(time_profile::TimeProfile, message::String)
    profiles = [
        OperationalProfile([5]),
        ScenarioProfile([5]),
        StrategicProfile([OperationalProfile([5])]),
        StrategicProfile([ScenarioProfile([5])]),
        StrategicProfile([RepresentativeProfile([OperationalProfile([5])])]),
        StrategicProfile([RepresentativeProfile([ScenarioProfile([5])])]),
        RepresentativeProfile([OperationalProfile([5])]),
        RepresentativeProfile([ScenarioProfile([5])]),
    ]
    for tp ∈ profiles
        @test_throws AssertionError EMB.check_representative_profile(tp, "")
    end

    # Check that wrong profiles for scenario indexable variables are identified
    # - EMB.check_scenario_profile(time_profile::TimeProfile, message::String)
    profiles = [
        OperationalProfile([5]),
        StrategicProfile([OperationalProfile([5])]),
        StrategicProfile([RepresentativeProfile([OperationalProfile([5])])]),
        StrategicProfile([RepresentativeProfile([ScenarioProfile([OperationalProfile([5])])])]),
        RepresentativeProfile([OperationalProfile([5])]),
        RepresentativeProfile([ScenarioProfile([OperationalProfile([5])])]),
        ScenarioProfile([OperationalProfile([5])]),
    ]
    for tp ∈ profiles
        @test_throws AssertionError EMB.check_scenario_profile(tp, "")
    end

    # Reactivate logging
    EMB.ASSERTS_AS_LOG = true
end

@testset "Checks - Nodes" begin

    # Resources used in the checks
    NG = ResourceEmit("NG", 0.2)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    aux = ResourceCarrier("aux", 0.0)

    # Function for setting up the system for testing `Sink` and `Source`
    function simple_graph(;
        src_cap::TimeProfile = FixedProfile(10),
        src_opex_var::TimeProfile = FixedProfile(10),
        src_opex_fixed::TimeProfile = FixedProfile(0),
        src_output::Dict = Dict(Power => 1),
        snk_cap::TimeProfile = OperationalProfile([6, 8, 10, 6, 8]),
        snk_pen::Dict = Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
        snk_input::Dict = Dict(Power => 1),
    )
        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat = 10)

        source =
        RefSource(
            "source",
            src_cap,
            src_opex_var,
            src_opex_fixed,
            src_output,
        )
        sink = RefSink(
            "sink",
            snk_cap,
            snk_pen,
            snk_input,
        )
        nodes = [source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return create_model(case, model), case, model
    end

    # Test that the fields of a Source are correctly checked
    # - check_node(n::Source, 𝒯, modeltype::EnergyModel)
    @testset "Source" begin
        # Sink used in the analysis
        # Test that a wrong capacity is caught by the checks.
        src_cap = FixedProfile(-4)
        @test_throws AssertionError simple_graph(;src_cap)

        # Test that a wrong output dictionary is caught by the checks.
        src_output = Dict(Power => -1)
        @test_throws AssertionError simple_graph(;src_output)

        # Test that a wrong fixed OPEX is caught by the checks.
        src_opex_fixed = FixedProfile(-5)
        @test_throws AssertionError simple_graph(;src_opex_fixed)

        # Test that a wrong profile for fixed OPEX is caught by the checks.
        # - check_fixed_opex(n::Node, 𝒯ᴵⁿᵛ, check_timeprofiles::Bool)
        src_opex_fixed = StrategicProfile([1])
        @test_throws AssertionError simple_graph(;src_opex_fixed)
        src_opex_fixed = OperationalProfile([1])
        @test_throws AssertionError simple_graph(;src_opex_fixed)
    end

    # Test that the fields of a Sink are correctly checked
    # - check_node(n::Sink, 𝒯, modeltype::EnergyModel)
    @testset "Sink" begin
        # Test that an inconsistent Sink.penalty dictionaries is caught by the checks.
        snk_pen = Dict(:surplus => FixedProfile(4), :def => FixedProfile(2))
        @test_throws AssertionError simple_graph(;snk_pen)

        # The penalties in this Sink node lead to an infeasible optimum. Test that the
        # checks forbids it.
        snk_pen = Dict(:surplus => FixedProfile(-4), :deficit => FixedProfile(2))
        @test_throws AssertionError simple_graph(;snk_pen)

        # Check that a wrong capacity in a sink is caught by the checks.
        snk_cap = OperationalProfile(-[6, 8, 10, 6, 8])
        @test_throws AssertionError simple_graph(;snk_cap)
    end

    # Function for setting up the system for testing a `NetworkNode`
    function simple_graph(;
        cap::TimeProfile = FixedProfile(25),
        opex_var::TimeProfile = FixedProfile(5.5),
        opex_fixed::TimeProfile = FixedProfile(0),
        input::Dict = Dict(NG => 2),
        output::Dict = Dict(Power => 1),
    )

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
            cap,
            opex_var,
            opex_fixed,
            input,
            output
        )
        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(Power => 1),
        )

        resources = [NG, Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat = 10)

        nodes = [source, network, sink]
        links = [
            Direct(12, source, network)
            Direct(23, network, sink)
        ]

        model = OperationalModel(
            Dict(CO2 => FixedProfile(100), NG => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0), NG => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return create_model(case, model), case, model
    end

    # Test that the fields of a NetworkNode are correctly checked
    # - check_node(n::NetworkNode, 𝒯, modeltype::EnergyModel)
    @testset "NetworkNode" begin

        # Test that a wrong capacity is caught by the checks.
        cap = FixedProfile(-25)
        @test_throws AssertionError simple_graph(;cap)

        # Test that a wrong fixed OPEX is caught by the checks.
        opex_fixed = FixedProfile(-100)
        @test_throws AssertionError simple_graph(;opex_fixed)

        # Test that a wrong input dictionary is caught by the checks.
        input = Dict(NG => -2)
        @test_throws AssertionError simple_graph(;input)

        # Test that a wrong output dictionary is caught by the checks.
        output = Dict(Power => -1)
        @test_throws AssertionError simple_graph(;output)
    end

    # Function for setting up the system for testing a `Storage` node
    function simple_graph(;
        charge = StorCapOpexVar(FixedProfile(-10), FixedProfile(10)),
        level = StorCapOpexFixed(FixedProfile(1e8), FixedProfile(2)),
        stor_res::Resource = Power,
        input::Dict = Dict(Power => 1, aux => 0.05),
        output::Dict = Dict(Power => 1),
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
            charge,
            level,
            stor_res,
            input,
            output,
        )

        sink = RefSink(
            "sink",
            FixedProfile(10),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(1000)),
            Dict(Power => 1),
        )

        T = TwoLevel(2, 2, SimpleTimes(5, 2); op_per_strat = 10)

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
        return create_model(case, model), case, model
    end

    # Test that the fields of a Storage are correctly checked
    # - check_node(n::Storage, 𝒯, modeltype::EnergyModel)
    @testset "Storage" begin

        # Test that a wrong capacities are caught by the checks.
        charge = StorCapOpexVar(FixedProfile(-10), FixedProfile(10))
        @test_throws AssertionError simple_graph(;charge)
        level = StorCapOpexVar(FixedProfile(-1e8), FixedProfile(2))
        @test_throws AssertionError simple_graph(;level)

        # Test that a wrong fixed OPEX is caught by the checks.
        level = StorCapOpexVar(FixedProfile(1e8), FixedProfile(-2))
        @test_throws AssertionError simple_graph(;level)

        # Test that a wrong input dictionary is caught by the checks.
        input = Dict(Power => -1, aux => 0.05)
        @test_throws AssertionError simple_graph(;input)
        input = Dict(Power => 1, aux => -0.05)
        @test_throws AssertionError simple_graph(;input)

        # Test that a wrong output dictionary is caught by the checks.
        output = Dict(Power => -1)
        @test_throws AssertionError simple_graph(;output)

        # Test that a wrong stored resource is caught by the checks.
        stor_res = aux
        @test_throws AssertionError simple_graph(;stor_res)
        stor_res = NG
        output = Dict(NG => -1)
        @test_throws AssertionError simple_graph(;stor_res, output)


    end
end

@testset "Checks - Links" begin

    # Resources used in the checks
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Auxiliary link used in the tests
    struct CheckLink <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        p::Resource
    end
    EMB.formulation(l::CheckLink) = Linear()
    EMB.inputs(l::CheckLink) = Resource[l.p]
    EMB.outputs(l::CheckLink) = Resource[l.p]

    # Function for setting up the system for testing `Sink` and `Source`
    function check_links(; res_src=Power, res_snk=Power)
        resources = [Power, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat = 10)

        av = GenAvailability("av", resources)
        sink = RefSink(
            "sink",
            OperationalProfile([6, 8, 10, 6, 8]),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(10)),
            Dict(res_src => 1),
        )

        # Test that a wrong capacity is caught by the checks.
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(res_snk => 1),
        )
        nodes = [av, source, sink]
        links = [Direct(12, source, sink)]
        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Case(T, resources, [nodes, links], [[get_nodes, get_links]])
        return case, model
    end

    # Test that the from and to fields are correctly checked
    # - check_elements(log_by_element, ℒ::Vector{<:Link}}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    case, model = check_links()
    av, source, sink = get_nodes(case)
    case.elements[2] = [Direct(12, GenAvailability("test", get_products(case)), sink)]
    @test_throws AssertionError create_model(case, model)
    case.elements[2] = [Direct(12, source, GenAvailability("test", get_products(case)))]
    @test_throws AssertionError create_model(case, model)
    case.elements[2] = [Direct(12, av, source)]
    @test_throws AssertionError create_model(case, model)
    case.elements[2] = [Direct(12, sink, av)]
    @test_throws AssertionError create_model(case, model)

    case, model = check_links(; res_snk = CO2)
    av, source, sink = get_nodes(case)
    case.elements[2] = [CheckLink(12, sink, av, Power)]
    @test_throws AssertionError create_model(case, model)

    case, model = check_links(; res_src = CO2)
    av, source, sink = get_nodes(case)
    case.elements[2] = [CheckLink(12, sink, av, Power)]
    @test_throws AssertionError create_model(case, model)

end

# Set the global again to false
EMB.TEST_ENV = false

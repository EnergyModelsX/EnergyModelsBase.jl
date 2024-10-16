@testset "Variable creation" begin
    m = JuMP.Model()

    function create_variable(range)
        @variable(m, same_name[range] ≥ 0)
    end

    # Create a variable named `same_name`, creating it once should be ok, but twice is not
    # allowed in jump, regardless of the indices.
    create_variable(1:4)
    try
        # Creating the variable a second time should fail. We depend on this behaviour in
        # the method `variables_nodes()` in `model.jl`.
        create_variable(5:8)
    catch e
        # Check that this causes an ErrorException. If this exception is thrown,
        # `variables_nodes` will continue to the next variable. If this behaviour in JuMP
        # changes, we must change how variables are created.
        @test isa(e, ErrorException)

        # Check that the error message is not changed.
        pre1 = "An object of name"
        pre2 = "is already attached to this model."
        @test occursin(pre1, e.msg)
        @test occursin(pre2, e.msg)
    end
end

@testset "Collect and sort types" begin
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 0.0)
    dict = Dict{Resource,Real}()
    vec = Resource[]

    source = RefSource("src", FixedProfile(5), FixedProfile(10), FixedProfile(5), dict)
    sink = RefSink("sink", FixedProfile(20), Dict{Symbol,TimeProfile}(), dict)
    stor = RefStorage{CyclicStrategic}(
        "stor",
        StorCapOpexVar(FixedProfile(60), FixedProfile(1)),
        StorCapOpexFixed(FixedProfile(1), FixedProfile(0)),
        Power,
        dict,
        dict,
    )
    stor_em = RefStorage{AccumulatingEmissions}(
        "stor-em",
        StorCapOpex(FixedProfile(1), FixedProfile(1), FixedProfile(1)),
        StorCap(FixedProfile(1)),
        CO2,
        dict,
        dict,
    )
    av = GenAvailability("av", vec)

    get_types(𝒩) = unique(map(n -> typeof(n), 𝒩))

    function test_type_ranking(node_types::Dict)
        @test node_types[EMB.Node] == 1
        @test node_types[Source] == 2
        @test node_types[Sink] == 2
        @test node_types[RefSource] == 3
        @test node_types[RefSink] == 3

        if haskey(node_types, NetworkNode)
            @test node_types[NetworkNode] == 2
            @test node_types[Availability] == 3
            @test node_types[GenAvailability] == 4
            @test node_types[Storage{CyclicStrategic}] == 3
            @test node_types[Storage{AccumulatingEmissions}] == 3
            @test node_types[RefStorage{CyclicStrategic}] == 4
            @test node_types[RefStorage{AccumulatingEmissions}] == 4
        end
    end

    function test_type_order(sorted_node_types)
        indexes = Dict(sorted_node_types .=> keys(sorted_node_types))

        @test indexes[EMB.Node] == 1
        @test indexes[Source] < indexes[RefSource]
        @test indexes[Sink] < indexes[RefSink]
        if haskey(indexes, NetworkNode)
            @test indexes[NetworkNode] < indexes[Storage{CyclicStrategic}]
            @test indexes[NetworkNode] < indexes[Storage{AccumulatingEmissions}]
            @test indexes[NetworkNode] < indexes[Availability]
            @test indexes[Storage{CyclicStrategic}] < indexes[RefStorage{CyclicStrategic}]
            @test indexes[Storage{AccumulatingEmissions}] <
                  indexes[RefStorage{AccumulatingEmissions}]
            @test indexes[Availability] < indexes[GenAvailability]
        end
    end

    @testset "Test 1" begin
        node_types = EMB.collect_types(get_types([source, sink]))

        test_type_ranking(node_types)
        sorted_node_types = EMB.sort_types(node_types)
        test_type_order(sorted_node_types)
    end

    @testset "Test 2" begin
        node_types = EMB.collect_types(get_types([source, sink, stor, stor_em, av]))

        test_type_ranking(node_types)
        sorted_node_types = EMB.sort_types(node_types)
        test_type_order(sorted_node_types)
    end
end

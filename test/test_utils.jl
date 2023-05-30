using JuMP

@testset "" begin
    m = JuMP.Model()

    function create_variable(range)
        @variable(m, same_name[range] ≥ 0)
    end

    # Create a varaible named `same_name`, creating it once should be ok, but twice is not
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
    end
end


@testset "Collect and sort types" begin
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 0.0)

    source = RefSource("src", FixedProfile(5), FixedProfile(10), FixedProfile(5),
        Dict(), [])
    sink = RefSink( "sink", FixedProfile(20), Dict(), Dict())
    stor = RefStorage("stor", FixedProfile(60), FixedProfile(1), FixedProfile(1),
        FixedProfile(0), Power, Dict(), Dict(), [])
    sink_em = RefStorageEmissions("sink-em", FixedProfile(1), FixedProfile(1),
        FixedProfile(1), FixedProfile(1), CO2, Dict(), Dict(), [])
    av = GenAvailability("av", Dict(), Dict())

    get_types(𝒩) = unique(map(n -> typeof(n), 𝒩))

    function test_type_ranking(node_types::Dict)
        @test node_types[EMB.Node] == 1
        @test node_types[Source] == 2
        @test node_types[Sink] == 2
        @test node_types[RefSource] == 3
        @test node_types[RefSink] == 3

        if haskey(node_types, Network)
            @test node_types[Network] == 2
            @test node_types[Availability] == 3
            @test node_types[GenAvailability] == 4

            @test node_types[Storage] == 3
            @test node_types[RefStorageEmissions] == 4
        end
    end

    function test_type_order(sorted_node_types)
        @info sorted_node_types
        indexes = Dict(sorted_node_types .=> keys(sorted_node_types))

        @test indexes[EMB.Node] == 1
        @test indexes[Source] < indexes[RefSource]
        @test indexes[Sink] < indexes[RefSink]
        if haskey(indexes, Network)
            @test indexes[Network] < indexes[Storage]
            @test indexes[Network] < indexes[Availability]
            @test indexes[Storage] < indexes[RefStorageEmissions]
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
        node_types = EMB.collect_types(get_types([source, sink, stor, sink_em, av]))

        test_type_ranking(node_types)
        sorted_node_types = EMB.sort_types(node_types)
        test_type_order(sorted_node_types)
    end
end

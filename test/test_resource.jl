
Power = ResourceCarrier("Power", 0.0)
Heat = ResourceCarrier("Heat", 0.0)
CO2 = ResourceEmit("CO2", 1.0)

𝒫 = [Power, Heat, CO2]

@testset "Resource - get resource types" begin
    # returns a Vector of DataTypes
    @test typeof(EMB.res_types(𝒫)) == Vector{DataType}

    # returns the correct number of unique resource types
    @test length(EMB.res_types(𝒫)) == 2
end

@testset "Resource - get resource vectors by type" begin
    # returns a Vector of Vectors
    @test typeof(EMB.res_types_seg(𝒫)) == Vector{Vector}

    # returns the correct number of segments
    @test length(EMB.res_types_seg(𝒫)) == 2

    # the length of the first segment should be 2 (2 ResourceCarriers)
    @test length(EMB.res_types_seg(𝒫)[1]) == 2

    # the length of the second segment should be 1 (1 ResourceEmit)
    @test length(EMB.res_types_seg(𝒫)[2]) == 1

end

# Add a new resource type and check that it is correctly identified by res_types and res_types_seg
struct TestResource <: Resource
    id::String
    a::Float64
    b::Int64
end

# Add a new resource of type TestResource to the resource vector
𝒫 = vcat(𝒫, [TestResource("Test", 0.5, 1)])

@testset "Resource - get resource types w/ custom resource type" begin
    # returns a Vector of DataTypes (now including TestResource)
    @test typeof(EMB.res_types(𝒫)) == Vector{DataType}

    # returns the correct number of unique resource types (now 3)
    @test length(EMB.res_types(𝒫)) == 3

end

@testset "Resource - get resource vectors by type w/ custom resource type" begin
    # returns the correct number of segments (now 3)
    @test length(EMB.res_types_seg(𝒫)) == 3

    # the length of the first segment should be 2 (2 ResourceCarriers)
    @test length(EMB.res_types_seg(𝒫)[1]) == 2

    # the length of the second segment should be 1 (1 ResourceEmit)
    @test length(EMB.res_types_seg(𝒫)[2]) == 1

    # the length of the third segment should be 1 (1 TestResource)
    @test length(EMB.res_types_seg(𝒫)[3]) == 1
end

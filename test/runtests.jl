using HiGHS
using JuMP
using Logging
using Test

using EnergyModelsBase
using TimeStruct

const EMB = EnergyModelsBase
const TS = TimeStruct

const TEST_ATOL = 1e-6
ENV["EMB_TEST"] = true # Set flag for example scripts to check if they are run as part of the tests

@testset "Base" begin
    @testset "Base | General" begin
        include("test_general.jl")
    end

    @testset "Base | ExtensionData" begin
        include("test_data.jl")
    end

    @testset "Base | Node" begin
        include("test_nodes.jl")
    end

    @testset "Base | Link" begin
        include("test_links.jl")
    end

    @testset "Base | Modeltype" begin
        include("test_modeltype.jl")
    end

    @testset "Base | Utilities" begin
        include("test_utils.jl")
    end

    @testset "Base | Checks" begin
        include("test_checks.jl")
    end

    @testset "Base | Deprecation" begin
        include("test_deprecation.jl")
    end

    @testset "Base | Investments" begin
        include("test_investments.jl")
    end

    @testset "Base | examples" begin
        include("test_examples.jl")
    end
end

using EnergyModelsBase
using HiGHS
using JuMP
using Test
using TimeStruct

const EMB = EnergyModelsBase
const TS = TimeStruct

const TEST_ATOL = 1e-6
ENV["EMB_TEST"] = true # Set flag for example scripts to check if they are run as part of the tests

@testset "EnergyModelsBase" begin
    include("test_general.jl")
    include("test_nodes.jl")
    include("test_modeltype.jl")
    include("test_examples.jl")
    include("test_utils.jl")
    include("test_checks.jl")
end

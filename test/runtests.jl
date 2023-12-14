using EnergyModelsBase
using HiGHS
using JuMP
using Test
using TimeStruct

const EMB = EnergyModelsBase
const TS = TimeStruct

const TEST_ATOL = 1e-6

@testset "EnergyModelsBase" begin
    include("example.jl")
    include("nodes.jl")
    include("modeltype.jl")
    include("test_examples.jl")
    include("test_utils.jl")
end

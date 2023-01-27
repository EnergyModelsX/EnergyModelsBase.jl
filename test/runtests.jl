using EnergyModelsBase
using HiGHS
using JuMP
using Test
using TimeStructures

const EMB = EnergyModelsBase
const TS = TimeStructures

const TEST_ATOL = 1e-6

@testset "EnergyModelsBase" begin
    include("user_interface.jl")
    include("nodes.jl")
    include("test_utils.jl")
end

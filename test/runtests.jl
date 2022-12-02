using EnergyModelsBase
using HiGHS
using JuMP
using Test
using TimeStructures

const EMB = EnergyModelsBase
const TS = TimeStructures

@testset "EnergyModelsBase" begin
    include("user_interface.jl")
    include("nodes.jl")
end

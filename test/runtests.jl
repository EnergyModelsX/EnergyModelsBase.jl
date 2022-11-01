using Test

using EnergyModelsBase
using TimeStructures
using JuMP
using HiGHS

const EMB = EnergyModelsBase
const TS = TimeStructures

@testset "EnergyModelsBase" begin

    include("user_interface.jl")
    include("nodes.jl")
end

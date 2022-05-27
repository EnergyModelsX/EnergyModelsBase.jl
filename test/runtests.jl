using Test

using EnergyModelsBase


@testset "EnergyModelsBase" begin

    include("user_interface.jl")
    include("nodes.jl")
end

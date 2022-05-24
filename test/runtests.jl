using Test

using EnergyModelsBase


@testset "EnergyModelsBase" begin

    include("utils.jl")

    include("user_interface.jl")
    include("nodes.jl")

end

using EnergyModelsBase
using Test

@testset "User interface" begin
    @test EnergyModelsBase.run_model("") == 0    
end

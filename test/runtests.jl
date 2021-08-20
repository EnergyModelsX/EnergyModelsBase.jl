using EnergyModelsBase
using Test
using TimeStructures
using JuMP
using GLPK

const EMB = EnergyModelsBase

m, data = EMB.run_model("",GLPK.Optimizer)

@testset "User interface" begin
    # Check for the objective value
    @test objective_value(m) ≈ 129056.305

    # Check for the total number of variables
    @test size(all_variables(m))[1] == 7188

    # Check for total emissions of both methane and CO2
    CH4 = data[:products][1]
    CO2 = data[:products][4]
    𝒯ᴵⁿᵛ = strategic_periods(data[:T])
    emissions_CO2 = [value.(m[:emissions_strategic])[t_inv,CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]
    @test emissions_CO2 <= [450, 400, 350, 300]
    emissions_CH4 = [value.(m[:emissions_strategic])[t_inv,CH4] for t_inv ∈ 𝒯ᴵⁿᵛ]
    @test emissions_CH4 <= [0, 0, 0, 0]
end
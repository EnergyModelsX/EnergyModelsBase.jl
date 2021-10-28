using EnergyModelsBase
using Test
using TimeStructures
using JuMP
using GLPK

const EMB = EnergyModelsBase

m, case = EMB.run_model("",GLPK.Optimizer)

@testset "User interface" begin
    # Check for the objective value
    @test objective_value(m) ≈ 129056.305

    # Check for the total number of variables
    @test size(all_variables(m))[1] == 7160

    # Check for total emissions of both methane and CO2
    global_data = case[:global_data]
    CH4         = case[:products][1]
    CO2         = case[:products][4]
    𝒯ᴵⁿᵛ        = strategic_periods(case[:T])
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @test value.(m[:emissions_strategic])[t_inv,CO2] <= global_data.Emission_limit[CO2][t_inv]
        @test value.(m[:emissions_strategic])[t_inv,CH4] <= global_data.Emission_limit[CH4][t_inv]
    end
end
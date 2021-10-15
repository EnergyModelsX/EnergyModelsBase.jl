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
    @test size(all_variables(m))[1] == 7160

    # Check for total emissions of both methane and CO2
    case = data[:case]
    CH4 = data[:products][1]
    CO2 = data[:products][4]
    𝒯ᴵⁿᵛ = strategic_periods(data[:T])
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @test value.(m[:emissions_strategic])[t_inv,CO2] <= case.Emission_limit[CO2][t_inv]
        @test value.(m[:emissions_strategic])[t_inv,CH4] <= case.Emission_limit[CH4][t_inv]
    end
end
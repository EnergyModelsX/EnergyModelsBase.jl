
using TimeStructures
using JuMP
using GLPK

const EMB = EnergyModelsBase


@testset "User interface" begin
    m, case = EMB.run_model("", nothing, GLPK.Optimizer)

    # Check for the objective value
    @test objective_value(m) ≈ 129056.305

    # Check for the total number of variables
    @test size(all_variables(m))[1] == 7160

    # Check for total emissions of both methane and CO2
    global_data = case[:global_data]
    CH4 = case[:products][1]
    CO2 = case[:products][4]
    𝒯ᴵⁿᵛ = strategic_periods(case[:T])

    @test sum(value.(m[:emissions_strategic])[t_inv, CO2]
              <=
              global_data.Emission_limit[CO2][t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    @test sum(value.(m[:emissions_strategic])[t_inv, CH4]
              <=
              global_data.Emission_limit[CH4][t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
end

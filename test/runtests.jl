using EnergyModelsBase
using Test
using JuMP
using GLPK

const EMB = EnergyModelsBase

data  = EMB.read_data("")
m = EMB.create_model(data)
EMB.set_optimizer(m, GLPK.Optimizer)
optimize!(m)
println(objective_value(m))

@testset "User interface" begin
    # Check for the objective value
    @test objective_value(m) == 28600.398214070225

    # Check for the total number of variables
    @test size(all_variables(m))[1] == 3306

    # Check for total emissions
    @test round(sum(value.(m[:emissions_total])[t,data[:products][4]] for t in data[:T])) == 450
end

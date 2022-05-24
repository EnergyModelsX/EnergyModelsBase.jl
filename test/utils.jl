using GLPK
using JuMP


function run_model(case)
    model = OperationalModel()
    m = create_model(case, model)
    set_optimizer(m, GLPK.Optimizer)
    optimize!(m)
    return m
end

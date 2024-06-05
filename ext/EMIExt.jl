module EMIExt

using EnergyModelsBase
using EnergyModelsInvestments
using JuMP
using TimeStruct
# using SparseVariables]

const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const TS = TimeStruct

include("checks.jl")
include("objective.jl")
include("variables_capex.jl")
include("constraints.jl")

"""
    has_investment(n::Storage, field::Symbol)

When the element type is a `Storage` node, checks that it contains investments for the field
`field`, that is `:charge`, `:level`, or `:discharge`.
"""
function EMI.has_investment(n::Storage, field::Symbol)
    (
        hasproperty(n, :data) &&
        !isnothing(findfirst(data->typeof(data)<:InvestmentData, node_data(n))) &&
        !isnothing(getproperty(investment_data(n), field))
    )
end

EMI.start_cap(n::Storage, t_inv, inv_data::NoStartInvData, cap) =
    capacity(getproperty(n, cap), t_inv)


end
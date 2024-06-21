module EMIExt

using EnergyModelsBase
using EnergyModelsInvestments
using JuMP
using TimeStruct
using SparseVariables

const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const TS = TimeStruct

include(joinpath("structures", "inv_data.jl"))
include(joinpath("structures", "model.jl"))
include(joinpath("structures", "legacy_constructor.jl"))
include("checks.jl")
include("objective.jl")
include("variables_capex.jl")
include("constraints.jl")

"""
    EMI.has_investment(n::EMB.Node)

For a given Node `n`, checks that it contains the required investment data.
"""
function EMI.has_investment(n::EMB.Node)
    (
        hasproperty(n, :data) &&
        !isnothing(findfirst(data -> typeof(data) <: InvestmentData, node_data(n)))
    )
end

"""
    EMI.has_investment(n::Storage, field::Symbol)

For a given `Storage` node, checks that it contains investments for the field
`field`, that is `:charge`, `:level`, or `:discharge`.
"""
function EMI.has_investment(n::Storage, field::Symbol)
    (
        hasproperty(n, :data) &&
        !isnothing(findfirst(data -> typeof(data) <: InvestmentData, node_data(n))) &&
        !isnothing(getproperty(EMI.investment_data(n), field))
    )
end

"""
    EMI.investment_data(n::EMB.Node)

Return the investment data of the Node `n`.
"""
EMI.investment_data(n::EMB.Node) =
    filter(data -> typeof(data) <: InvestmentData, node_data(n))[1]

"""
    EMI.investment_data(inv_data::SingleInvData)

Return the investment data of the investment data `SingleInvData`.
"""
EMI.investment_data(inv_data::SingleInvData) = inv_data.cap

"""
    EMI.investment_data(element, field::Symbol)

Return the investment data of the type `element` of the capacity `field`.
"""
EMI.investment_data(n::EMB.Node, field::Symbol) = getproperty(investment_data(n), field)

EMI.start_cap(n::EMB.Node, t_inv, inv_data::NoStartInvData, cap) =
    capacity(n, t_inv)
EMI.start_cap(n::Storage, t_inv, inv_data::NoStartInvData, cap) =
    capacity(getproperty(n, cap), t_inv)

end

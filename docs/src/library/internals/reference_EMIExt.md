# [Internals - EnergyModelsInvestment extension](@id lib-int-EMIext)

## [Index](@id lib-int-EMIext-idx)

```@index
Pages = ["reference_EMIExt.md"]
```

```@meta
CurrentModule =
    Base.get_extension(EMB, :EMIExt)
```

## [Extension](@id lib-int-EMIext-ext)

### [Types](@id lib-int-EMIext-ext-types)

```@docs
InvestmentModel
SingleInvData
StorageInvData
```

### [Functions](@id lib-int-EMIext-fun)

```@docs
check_inv_data
```

## [EnergyModelsBase](@id lib-int-EMIext-EMB)

### [Methods](@id lib-int-EMIext-met)

```@docs
EMB.variables_ext_data(m, _::Type{SingleInvData}, 𝒩ᴵⁿᵛ::Vector{<:EMB.Node}, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)
EMB.objective_invest(m, 𝒩::Vector{<:EMB.Node}, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::AbstractInvestmentModel)
EMB.constraints_capacity_installed(m, n::EMB.Node, 𝒯::TimeStructure, modeltype::AbstractInvestmentModel)
EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)
EMB.check_link_data(l::Link, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)
```

## [EnergyModelsInvestments](@id lib-int-EMIext-EMI)

### [Methods](@id lib-int-EMIext-met)

```@docs
EMI.has_investment
EMI.investment_data
```

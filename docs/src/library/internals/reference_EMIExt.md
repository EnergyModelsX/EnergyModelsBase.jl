# Internals - EnergyModelsInvestment extension

## Index

```@index
Pages = ["reference_EMIExt.md"]
```

```@meta
CurrentModule =
    Base.get_extension(EMB, :EMIExt)
```

## Extension

### Types

```@docs
InvestmentModel
SingleInvData
StorageInvData
```

### Methods

```@docs
check_inv_data
objective_invest
```

## EnergyModelsBase

### Methods

```@docs
EMB.variables_capex(m, 𝒩::Vector{<:EMB.Node}, 𝒯, modeltype::AbstractInvestmentModel)
EMB.objective(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::AbstractInvestmentModel)
EMB.constraints_capacity_installed(m, n::EMB.Node, 𝒯::TimeStructure, modeltype::AbstractInvestmentModel)
EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)
```

## EnergyModelsInvestments

### Constructors

The following constructors are only relevant for the legacy constructors introduced within the extension.
They do not provide any additional information.

```@docs
EMI.BinaryInvestment
EMI.ContinuousInvestment
EMI.DiscreteInvestment
EMI.FixedInvestment
EMI.PeriodLife
EMI.RollingLife
EMI.SemiContinuousInvestment
EMI.SemiContinuousOffsetInvestment
EMI.StudyLife
```

### Methods

```@docs
EMI.has_investment
EMI.investment_data
```

""" Abstract type for differentation between types of models (investment, operational, ...)."""
abstract type EnergyModel end

"""
    OperationalModel <: EnergyModel

Operational Energy Model without investments.

# Fields
- **`emission_limit::Dict{<:ResourceEmit, <:TimeProfile}`** is a dictionary with
  individual emission limits as `TimeProfile` for each emission resource [`ResourceEmit`](@ref).
- **`emission_price::Dict{<:ResourceEmit, <:TimeProfile}`** are the emission costs for each
  emission resources [`ResourceEmit`](@ref).
- **`co2_instance`** is a [`ResourceEmit`](@ref) and corresponds to the type used for CO₂.
"""
struct OperationalModel <: EnergyModel
    emission_limit::Dict{<:ResourceEmit,<:TimeProfile}
    emission_price::Dict{<:ResourceEmit,<:TimeProfile}
    co2_instance::ResourceEmit
end

"""
    emission_limit(modeltype::EnergyModel)
    emission_limit(modeltype, p::ResourceEmit)
    emission_limit(modeltype, p::ResourceEmit, t_inv::TS.AbstractStrategicPeriod)

Returns the emission limit of EnergyModel `model` as dictionary with `TimeProfile`s for
each [`ResourceEmit`](@ref), as `TimeProfile` for [`ResourceEmit`](@ref) `p` or, in
strategic period `t_inv` for [`ResourceEmit`](@ref) `p`.
"""
emission_limit(modeltype::EnergyModel) = modeltype.emission_limit
emission_limit(modeltype, p::ResourceEmit) = modeltype.emission_limit[p]
emission_limit(modeltype, p::ResourceEmit, t_inv::TS.AbstractStrategicPeriod) =
    modeltype.emission_limit[p][t_inv]

"""
    emission_price(modeltype::EnergyModel)
    emission_price(modeltype, p::ResourceEmit)
    emission_price(modeltype, p::ResourceEmit, t_inv::TS.TimePeriod)

Returns the emission price of EnergyModel `model` as dictionary with `TimeProfile`s for
each [`ResourceEmit`](@ref), as `TimeProfile` for [`ResourceEmit`](@ref) `p` or, in
operational period `t` for [`ResourceEmit`](@ref) `p`.
"""
emission_price(modeltype::EnergyModel) = modeltype.emission_price
emission_price(modeltype, p::ResourceEmit) =
    haskey(modeltype.emission_price, p) ? modeltype.emission_price[p] : 0
emission_price(modeltype, p::ResourceEmit, t::TS.TimePeriod) =
    haskey(modeltype.emission_price, p) ? modeltype.emission_price[p][t] : 0

"""
    co2_instance(modeltype::EnergyModel)

Returns the CO₂ instance used in modelling.
"""
co2_instance(modeltype::EnergyModel) = modeltype.co2_instance

"""
    AbstractInvestmentModel <: EnergyModel

An abstract investment model type.

This abstract model type should be used when creating additional [`EnergyModel`](@ref) types
that should utilize investments.

!!! note
    Although it is declared within `EnergyModelsBase`, its concrete is only accessible if
    `EnergyModelsInvestments` is loaded

An example for additional types is given by the inclusion of, *e.g.*, `SDDP`.
"""
abstract type AbstractInvestmentModel <: EnergyModel end

"""
    InvestmentModel <: AbstractInvestmentModel

A concrete basic investment model type based on the standard [`OperationalModel`](@ref).
The concrete basic investment model is similar to an `OperationalModel`, but allows for
investments and additional discounting of future years.

!!! note
    Although it is declared within `EnergyModelsBase`, its concrete is only accessible if
    `EnergyModelsInvestments` is loaded

# Fields
- **`emission_limit::Dict{<:ResourceEmit, <:TimeProfile}`** is a dictionary with
  individual emission limits as `TimeProfile` for each emission resource [`ResourceEmit`](@ref).
- **`emission_price::Dict{<:ResourceEmit, <:TimeProfile}`** are the emission costs for each
  emission resources [`ResourceEmit`](@ref).
- **`co2_instance`** is a [`ResourceEmit`](@ref) and corresponds to the type used for CO₂.
- **`r::Float64`** is the discount rate in the investment optimization.
"""
abstract type InvestmentModel <: AbstractInvestmentModel end

"""
    discount_rate(modeltype::AbstractInvestmentModel)

Returns the discount rate of `AbstractInvestmentModel` modeltype.
"""
discount_rate(modeltype::AbstractInvestmentModel) = modeltype.r

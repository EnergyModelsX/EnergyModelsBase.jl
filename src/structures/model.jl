""" Abstract type for differentation between types of models (investment, operational, ...)."""
abstract type EnergyModel end

"""
    OperationalModel <: EnergyModel

Operational Energy Model without investments.

# Fields
- **`emission_limit::Dict{<:ResourceEmit, <:TimeProfile}`** is a dictionary with
  individual emission limits as `TimeProfile` for each emission resource [`ResourceEmit`](@ref).
- **`emission_price::Dict{<:ResourceEmit, <:TimeProfile}`** are the prices for the
  different emissions types considered.
- **`co2_instance`** is a [`ResourceEmit`](@ref) and corresponds to the type used for CO₂.
"""
struct OperationalModel <: EnergyModel
    emission_limit::Dict{<:ResourceEmit,<:TimeProfile}
    emission_price::Dict{<:ResourceEmit,<:TimeProfile}
    co2_instance::ResourceEmit
end

"""
    emission_limit(modeltype)

Returns the emission limit of EnergyModel `model` as dictionary with `TimeProfile`s for
each [`ResourceEmit`](@ref).
"""
emission_limit(modeltype) = modeltype.emission_limit
"""
    emission_limit(modeltype, p::ResourceEmit)

Returns the emission limit of EnergyModel `model` and [`ResourceEmit`](@ref) `p` as
`TimeProfile`.
"""
emission_limit(modeltype, p::ResourceEmit) = modeltype.emission_limit[p]
"""
    emission_limit(modeltype, p::ResourceEmit, t_inv::TS.StrategicPeriod)

Returns the emission limit of EnergyModel `model` and [`ResourceEmit`](@ref) `p`
in strategic period period `t_inv`.
"""
emission_limit(modeltype, p::ResourceEmit, t_inv::TS.StrategicPeriod) =
    modeltype.emission_limit[p][t_inv]

"""
    emission_price(modeltype::EnergyModel)

Returns the emission price of EnergyModel `model` as dictionary with `TimeProfile`s for
each [`ResourceEmit`](@ref).
"""
emission_price(modeltype) = modeltype.emission_price
"""
    emission_price(modeltype, p::ResourceEmit)

Returns the emission price of EnergyModel `modeltype` and ResourceEmit `p` as `TimeProfile`.
If no emission price is specified for the ResourceEmit `p`, the function returns 0
"""
emission_price(modeltype, p::ResourceEmit) =
    haskey(modeltype.emission_price, p) ? modeltype.emission_price[p] : 0
"""
    emission_price(modeltype, p::ResourceEmit, t_inv::TS.StrategicPeriod)

Returns the emission price of EnergyModel `modeltype` and ResourceEmit `p` in strategic
period `t_inv`.
If no emission price is specified for the ResourceEmit `p`, the function returns 0
"""
emission_price(modeltype, p::ResourceEmit, t_inv::TS.StrategicPeriod) =
    haskey(modeltype.emission_price, p) ? modeltype.emission_price[p][t_inv] : 0

"""
    co2_instance(modeltype)

Returns the CO₂ instance used in modelling.
"""
co2_instance(modeltype) = modeltype.co2_instance


""" An abstract investment model type.

This abstract model type should be used when creating additional `EnergyModel` types that
should utilize investments.
An example for additional types is given by the inclusion of, *e.g.*, `SDDP`.
"""
abstract type AbstractInvestmentModel <: EnergyModel end

"""
A concrete basic investment model type based on the standard `OperationalModel`.
The concrete basic investment model is similar to an `OperationalModel`, but allows for
investments and additional discounting of future years.

# Fields
- **`emission_limit::Dict{<:ResourceEmit, <:TimeProfile}`** are the emission caps for the
  different emissions types considered.
- **`emission_price::Dict{<:ResourceEmit, <:TimeProfile}`** are the prices for the
  different emissions types considered.
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO₂.
- **`r::Float64`** is the discount rate in the investment optimization.
"""
abstract type InvestmentModel <: AbstractInvestmentModel end

"""
    discount_rate(modeltype::AbstractInvestmentModel)

Returns the discount rate of `EnergyModel` modeltype
"""
discount_rate(modeltype::AbstractInvestmentModel) = modeltype.r

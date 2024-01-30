""" Abstract type for differentation between types of models (investment, operational, ...)."""
abstract type EnergyModel end

"""
Operational Energy Model without investments.

# Fields
- **`emission_limit::Dict{ResourceEmit, <:TimeProfile}`** is a dictionary with \
individual emission limits as `TimeProfile` for each emission resource `ResourceEmit`.\n
- **`emission_price::Dict{ResourceEmit, <:TimeProfile}`** are the prices for the \
different emissions types considered.\n
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO₂.\n
"""
struct OperationalModel <: EnergyModel
    emission_limit::Dict{ResourceEmit, <:TimeProfile}
    emission_price::Dict{ResourceEmit, <:TimeProfile}
    co2_instance::ResourceEmit
end

"""
    emission_limit(model::EnergyModel)

Returns the emission limit of EnergyModel `model` as dictionary with `TimeProfile`s for
each `ResourceEmit`.
"""
emission_limit(model::EnergyModel) = model.emission_limit
"""
    emission_limit(model::EnergyModel, p::ResourceEmit)

Returns the emission limit of EnergyModel `model` and ResourceEmit `p` as `TimeProfile`.
"""
emission_limit(model::EnergyModel, p::ResourceEmit) = model.emission_limit[p]
"""
    emission_limit(model::EnergyModel, p::ResourceEmit, t_inv::TS.StrategicPeriod)

Returns the emission limit of EnergyModel `model` and ResourceEmit `p` in strategic period
period `t_inv`.
"""
emission_limit(model::EnergyModel, p::ResourceEmit, t_inv::TS.StrategicPeriod) =
    model.emission_limit[p][t_inv]

"""
    emission_price(model::EnergyModel)

Returns the emission price of EnergyModel `model` as dictionary with `TimeProfile`s for
each `ResourceEmit`.
"""
emission_price(model::EnergyModel) = model.emission_price
"""
    emission_price(model::EnergyModel, p::ResourceEmit)

Returns the emission price of EnergyModel `model` and ResourceEmit `p` as `TimeProfile`.
If no emission price is specified for the ResourceEmit `p`, the function returns 0
"""
emission_price(model::EnergyModel, p::ResourceEmit) =
    haskey(model.emission_price, p) ? model.emission_price[p] : 0
"""
    emission_price(model::EnergyModel, p::ResourceEmit, t_inv::TS.StrategicPeriod)

Returns the emission price of EnergyModel `model` and ResourceEmit `p` in strategic
period `t_inv`.
If no emission price is specified for the ResourceEmit `p`, the function returns 0
"""
emission_price(model::EnergyModel, p::ResourceEmit, t_inv::TS.StrategicPeriod) =
    haskey(model.emission_price, p) ? model.emission_price[p][t_inv] : 0

"""
    co2_instance(model::EnergyModel)

Returns the CO₂ instance used in modelling.
"""
co2_instance(model::EnergyModel) = model.co2_instance

""" Abstract type for differentation between types of models (investment, operational, ...)."""
abstract type EnergyModel end

"""
Operational Energy Model without investments.

# Fields
- **`emission_limit`** is a dictionary with individual emission limits as `TimeProfile` for each
emission resource `ResourceEmit`.\n
- **`emission_price::Dict{ResourceEmit, TimeProfile}`** are the prices for the different
emissions types considered.\n
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO2.\n
"""
struct OperationalModel <: EnergyModel
    emission_limit::Dict{ResourceEmit, TimeProfile}
    emission_price::Dict{ResourceEmit, TimeProfile}
    co2_instance::ResourceEmit
end

"""
    emission_limit(model)

Returns the emission limit of EnergyModel `model` as dictionary with `TimeProfile`s for
each `ResourceEmit`.
"""
emission_limit(model) = model.emission_limit
"""
    emission_limit(model, p)

Returns the emission limit of EnergyModel `model` and ResourceEmit `p` as `TimeProfile`.
"""
emission_limit(model, p) = model.emission_limit[p]
"""
    emission_limit(model, p, t)

Returns the emission limit of EnergyModel `model` and ResourceEmit `p` in operational
period `t`.
"""
emission_limit(model, p, t) = model.emission_limit[p][t]

"""
    emission_price(model)

Returns the emission price of EnergyModel `model` as dictionary with `TimeProfile`s for
each `ResourceEmit`.
"""
emission_price(model) = model.emission_price
"""
    emission_price(model, p)

Returns the emission price of EnergyModel `model` and ResourceEmit `p` as `TimeProfile`.
If no emission price is specified for the ResourceEmit `p`, the function returns 0
"""
emission_price(model, p) = haskey(model.emission_price, p) ? model.emission_price[p] : 0
"""
    emission_price(model, p, t)

Returns the emission price of EnergyModel `model` and ResourceEmit `p` in operational
period `t`.
If no emission price is specified for the ResourceEmit `p`, the function returns 0
"""
emission_price(model, p, t) = haskey(model.emission_price, p) ? model.emission_price[p][t] : 0

"""
    co2_instance(model)

Returns the CO2 instance used in modelling.
"""
co2_instance(model) = model.co2_instance

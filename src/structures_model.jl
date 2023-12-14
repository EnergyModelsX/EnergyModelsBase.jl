""" Abstract type for differentation between types of models (investment, operational, ...)."""
abstract type EnergyModel end

"""
Operational Energy Model without investments.

# Fields
- **`emission_limit`** is a dictionary with individual emission limits as `TimeProfile` for each
emission resource `ResourceEmit`.\n
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO2.\n
"""
struct OperationalModel <: EnergyModel
    emission_limit::Dict{ResourceEmit, TimeProfile}
    co2_instance::ResourceEmit
end

emission_limit(model, p, t) = model.emission_limit[p][t]
emission_limit(model) = model.emission_limit
co2_instance(model) = model.co2_instance

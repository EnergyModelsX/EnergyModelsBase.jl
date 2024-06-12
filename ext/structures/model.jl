"""
A concrete basic investment model type based on the standard `OperationalModel` as declared
in `EnergyModelsBase`.
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
struct InvestmentModel <: EMB.InvestmentModel
    emission_limit::Dict{<:ResourceEmit, <:TimeProfile}
    emission_price::Dict{<:ResourceEmit, <:TimeProfile}
    co2_instance::ResourceEmit
    r::Float64
    function InvestmentModel(emission_limit, emission_price, co2_instance, r)
        return new(emission_limit, emission_price, co2_instance, r)
    end
end
EMB.InvestmentModel(args...) = InvestmentModel(args...)

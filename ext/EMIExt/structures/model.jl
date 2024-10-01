"""
    InvestmentModel <: EMB.InvestmentModel

Internal type for [`InvestmentModel`](@ref EMB.InvestmentModel). The introduction of an
internal type is necessary as extensions do not allow to export functions or types.
"""
struct InvestmentModel <: EMB.InvestmentModel
    emission_limit::Dict{<:ResourceEmit,<:TimeProfile}
    emission_price::Dict{<:ResourceEmit,<:TimeProfile}
    co2_instance::ResourceEmit
    r::Float64
    function InvestmentModel(emission_limit, emission_price, co2_instance, r)
        return new(emission_limit, emission_price, co2_instance, r)
    end
end
EMB.InvestmentModel(args...) = InvestmentModel(args...)

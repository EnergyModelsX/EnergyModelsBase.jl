"""
    EMB.objective(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::AbstractInvestmentModel)

Create objective function overloading the default from EMB for `AbstractInvestmentModel`.

Maximize Net Present Value from investments (CAPEX) and operations (OPEX and emission costs)

## TODO:
Consider adding contributions from
 - revenue (as positive variable, adding positive)
 - maintenance based on usage (as positive variable, adding negative)
These variables would need to be introduced through the package `SparsVariables`.

Both are not necessary, as it is possible to include them through the OPEX values, but it
would be beneficial for a better separation and simpler calculations from the results.
"""
function EMB.objective(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::AbstractInvestmentModel)

    # Extraction of the individual subtypes for investments in nodes
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Filtering through the individual links
    disc = Discounter(discount_rate(modeltype), 𝒯)

    # Calculation of the OPEX contribution
    opex = JuMP.Containers.DenseAxisArray[]
    for elements ∈ (𝒩, ℒ, 𝒫)
        push!(opex, EMB.objective_operational(m, elements, 𝒯ᴵⁿᵛ, modeltype))
    end

    # Calculation of the CAPEX contribution
    capex = JuMP.Containers.DenseAxisArray[]
    for elements ∈ (𝒩, ℒ)
        push!(capex, objective_invest(m, elements, 𝒯ᴵⁿᵛ, modeltype))
    end
    # Calculation of the objective function.
    @objective(m, Max,
        -sum(
            sum(elements[t_inv] for elements ∈ opex) *
            duration_strat(t_inv) * objective_weight(t_inv, disc; type = "avg") +
            sum(elements[t_inv] for elements ∈ capex) *
            objective_weight(t_inv, disc)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
    )
end
"""
    objective_invest(m, elements, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::EnergyModel)

Create JuMP expressions indexed over the investment periods `𝒯ᴵⁿᵛ` for different elements.
The expressions correspond to the investments into the different elements. They are not
discounted and do not take the duration of the investment periods into account.

By default, objective expressions are included for:
- `elements = 𝒩::Vector{<:Node}`. In the case of a vector of nodes, the function returns the
  sum of the capital expenditures for all nodes whose method of the function
  [`has_investment`](@ref) returns true. In the case of [`Storage`](@ref) nodes, all capacity
  investments are considired
- `elements = 𝒩::Vector{<:Link}`. In the case of a vector of links, the function returns the
  sum of the capital expenditures for all links whose method of the function
  [`has_investment`](@ref) returns true.

!!! note "Default function"
    It is also possible to provide a tuple `𝒳` for only operational or only investment
    objective contributions. In this situation, the expression returns a value of 0 for all
    investment periods.
"""
function objective_invest(
    m,
    𝒩::Vector{<:EMB.Node},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::AbstractInvestmentModel,
)
    # Declaration of the required subsets
    𝒩ᴵⁿᵛ = filter(has_investment, filter(!EMB.is_storage, 𝒩))
    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    𝒩ˡᵉᵛᵉˡ = filter(n -> has_investment(n, :level), 𝒩ˢᵗᵒʳ)
    𝒩ᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :charge), 𝒩ˢᵗᵒʳ)
    𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :discharge), 𝒩ˢᵗᵒʳ)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:cap_capex][n, t_inv] for n ∈ 𝒩ᴵⁿᵛ) +
        sum(m[:stor_level_capex][n, t_inv] for n ∈ 𝒩ˡᵉᵛᵉˡ) +
        sum(m[:stor_charge_capex][n, t_inv] for n ∈ 𝒩ᶜʰᵃʳᵍᵉ) +
        sum(m[:stor_discharge_capex][n, t_inv] for n ∈ 𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ)
    )
end
function objective_invest(
    m,
    ℒ::Vector{<:Link},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::AbstractInvestmentModel,
)
    # Declaration of the required subsets
    ℒᴵⁿᵛ = filter(has_investment, ℒ)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:link_cap_capex][l, t_inv] for l ∈ ℒᴵⁿᵛ)
    )
end
objective_invest(m, _, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, _::AbstractInvestmentModel) =
    @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 0)

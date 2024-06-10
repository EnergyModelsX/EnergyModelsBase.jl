"""
    EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

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
function EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

    # Extraction of the individual subtypes for investments in nodes
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᶜᵃᵖ = EMB.nodes_not_av(𝒩)                          # Nodes with capacity
    𝒩ᴵⁿᵛ = filter(EMI.has_investment, filter(!EMB.is_storage, 𝒩))
    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    𝒩ˡᵉᵛᵉˡ = filter(n -> EMI.has_investment(n, :level), 𝒩ˢᵗᵒʳ)
    𝒩ᶜʰᵃʳᵍᵉ = filter(n -> EMI.has_investment(n, :charge), 𝒩ˢᵗᵒʳ)
    𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ = filter(n -> EMI.has_investment(n, :discharge), 𝒩ˢᵗᵒʳ)

    𝒫ᵉᵐ  = filter(EMB.is_resource_emit, 𝒫)              # Emissions resources

    disc = Discounter(EMI.discount_rate(modeltype), 𝒯)

    # Calculation of the OPEX contribution
    opex = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum((m[:opex_var][n, t_inv] + m[:opex_fixed][n, t_inv]) for n ∈ 𝒩ᶜᵃᵖ)
    )

    # Calculation of the emission costs contribution
    emissions = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:emissions_strategic][t_inv, p] * emission_price(modeltype, p, t_inv) for p ∈ 𝒫ᵉᵐ)
    )

    # Calculation of the capital cost contribution
    capex_cap = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:cap_capex][n, t_inv]  for n ∈ 𝒩ᴵⁿᵛ)
    )

    # Calculation of the capital cost contribution of storage nodes
    capex_stor = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:stor_level_capex][n, t_inv] for n ∈ 𝒩ˡᵉᵛᵉˡ) +
        sum(m[:stor_charge_capex][n, t_inv] for n ∈ 𝒩ᶜʰᵃʳᵍᵉ) +
        sum(m[:stor_discharge_capex][n, t_inv] for n ∈ 𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ)
    )

    # Calculation of the objective function.
    @objective(m, Max,
        -sum(
            (opex[t_inv] + emissions[t_inv]) *
                duration_strat(t_inv) * objective_weight(t_inv, disc; type="avg") +
            (capex_cap[t_inv] + capex_stor[t_inv]) * objective_weight(t_inv, disc)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
    )
end

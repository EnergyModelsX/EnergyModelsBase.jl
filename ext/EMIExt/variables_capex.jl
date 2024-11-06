"""
    EMB.variables_capex(m, 𝒩, 𝒯, modeltype::AbstractInvestmentModel)

Create variables for the capital costs for the investments in storage and technology nodes.

Additional variables for investment in capacity:
* `:cap_capex` - CAPEX costs for a technology
* `:cap_current` - installed capacity for storage in each strategic period
* `:cap_add` - added capacity
* `:cap_rem` - removed capacity
* `:cap_invest_b` - binary variable whether investments in capacity are happening
* `:cap_remove_b` - binary variable whether investments in capacity are removed


Additional variables for investment in storage:
* `:stor_level_capex` - CAPEX costs for increases in the capacity of a storage
* `:stor_level_current` - installed capacity for storage in each strategic period
* `:stor_level_add` - added capacity
* `:stor_level_rem` - removed capacity
* `:stor_level_invest_b` - binary variable whether investments in capacity are happening
* `:stor_level_remove_b` - binary variable whether investments in capacity are removed

* `:stor_charge_capex` - CAPEX costs for increases in the rate of a storage
* `:stor_charge_current` - installed rate for storage in each strategic period
* `:stor_charge_add` - added rate
* `:stor_charge_rem` - removed rate
* `:stor_charge_invest_b` - binary variable whether investments in rate are happening
* `:stor_charge_remove_b` - binary variable whether investments in rate are removed
"""
function EMB.variables_capex(m, 𝒩, 𝒯, modeltype::AbstractInvestmentModel)
    𝒩ᴵⁿᵛ = filter(has_investment, filter(!EMB.is_storage, 𝒩))
    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    𝒩ˡᵉᵛᵉˡ = filter(n -> has_investment(n, :level), 𝒩ˢᵗᵒʳ)
    𝒩ᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :charge), 𝒩ˢᵗᵒʳ)
    𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :discharge), 𝒩ˢᵗᵒʳ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add investment variables for reference nodes for each strategic period:
    @variable(m, cap_capex[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_current[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_add[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_rem[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_invest_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, cap_remove_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)

    # Add storage specific investment variables for each strategic period:
    @variable(m, stor_level_capex[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_level_current[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_level_add[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_level_rem[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_level_invest_b[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, stor_level_remove_b[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)

    @variable(m, stor_charge_capex[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_charge_current[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_charge_add[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_charge_rem[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_charge_invest_b[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, stor_charge_remove_b[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)

    @variable(m, stor_discharge_capex[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_discharge_current[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_discharge_add[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_discharge_rem[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(
        m,
        stor_discharge_invest_b[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0;
        container = IndexedVarArray
    )
    @variable(
        m,
        stor_discharge_remove_b[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0;
        container = IndexedVarArray
    )
end

"""
    EMB.variables_links_capex(m, ℒ, 𝒯, modeltype::AbstractInvestmentModel)

Create variables for the capital costs for the investments in [`Link`](@ref)s.

Additional variables for investment in capacity:
* `:link_cap_capex` - CAPEX costs for a technology
* `:link_cap_current` - installed capacity for storage in each strategic period
* `:link_cap_add` - added capacity
* `:link_cap_rem` - removed capacity
* `:link_cap_invest_b` - binary variable whether investments in capacity are happening
* `:link_cap_remove_b` - binary variable whether investments in capacity are removed
"""
function EMB.variables_links_capex(m, ℒ, 𝒯, modeltype::AbstractInvestmentModel)
    ℒᴵⁿᵛ = filter(has_investment, ℒ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add investment variables for reference nodes for each strategic period:
    @variable(m, link_cap_capex[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, link_cap_current[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, link_cap_add[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, link_cap_rem[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, link_cap_invest_b[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, link_cap_remove_b[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
end

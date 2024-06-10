"""
    EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

Create variables for the capital costs for the invesments in storage and
technology nodes.

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
function EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

    𝒩ᴵⁿᵛ = filter(EMI.has_investment, filter(!EMB.is_storage, 𝒩))
    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    𝒩ˡᵉᵛᵉˡ = filter(n -> EMI.has_investment(n, :level), 𝒩ˢᵗᵒʳ)
    𝒩ᶜʰᵃʳᵍᵉ = filter(n -> EMI.has_investment(n, :charge), 𝒩ˢᵗᵒʳ)
    𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ = filter(n -> EMI.has_investment(n, :discharge), 𝒩ˢᵗᵒʳ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add investment variables for reference nodes for each strategic period:
    @variable(m, cap_capex[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, cap_current[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)     # Installed capacity
    @variable(m, cap_add[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)        # Add capacity
    @variable(m, cap_rem[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)        # Remove capacity
    @variable(m, cap_invest_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
    @variable(m, cap_remove_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)

    # Add storage specific investment variables for each strategic period:
    @variable(m, stor_level_capex[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, stor_level_current[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0)    # Installed capacity
    @variable(m, stor_level_add[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0)        # Add capacity
    @variable(m, stor_level_rem[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0)        # Remove capacity
    @variable(m, stor_level_invest_b[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
    @variable(m, stor_level_remove_b[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)

    @variable(m, stor_charge_capex[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, stor_charge_current[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)   # Installed power/rate
    @variable(m, stor_charge_add[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)       # Add power
    @variable(m, stor_charge_rem[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)       # Remove power
    @variable(m, stor_charge_invest_b[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
    @variable(m, stor_charge_remove_b[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)

    @variable(m, stor_discharge_capex[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, stor_discharge_current[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)   # Installed power/rate
    @variable(m, stor_discharge_add[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)       # Add power
    @variable(m, stor_discharge_rem[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)       # Remove power
    @variable(m, stor_discharge_invest_b[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
    @variable(m, stor_discharge_remove_b[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
end


"""
    EMB.variables_ext_data(m, _::Type{SingleInvData}, 𝒩ᴵⁿᵛ::Vector{<:EMB.Node}, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)
    EMB.variables_ext_data(m, _::Type{StorageInvData}, 𝒩ᴵⁿᵛ::Vector{<:EMB.Node}, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)
    EMB.variables_ext_data(m, _::Type{SingleInvData}, 𝒩ᴵⁿᵛ::Vector{<:Link}, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

Declaration of different capital expenditures (CAPEX) variables for the element types
introduced in `EnergyModelsBase`. CAPEX variables are only introduced for elements that have
in investments as identified through the function
[`EMI.has_investment`](@ref EnergyModelsInvestments.has_investment). All investment
variables are declared for all investment periods.

`EnergyModelsBase` introduces two elements for an energy system, and hence, provides the
user with two individual methods for both `𝒩::Vector{<:EMB.Node}` and 𝒩::Vector{<:Link}.

!!! note "Variables and naming conventions"
    The individual capacities require the same variable although with different names.
    Hence, `**prefix**` should be replaced in the following to

    - `cap` for all nodes with investments except for [`Storage`](@ref) and
      [`Availability`](@ref) nodes,
    - `stor_level` for the storage level capacity of [`Storage`](@ref) nodes,
    - `stor_charge` for the charge capacity of [`Storage`](@ref) nodes,
    - `stor_discharge` for the discharge capacity of [`Storage`](@ref) nodes, and
    - `link_cap` for [`Link`]s.

    The individual variables are then given by:

    - `**prefix**_capex` are the capital expenditures in node `n` in investment period
      `t_inv`. The CAPEX variable take into account the invested capacity.
    - `**prefix**_current` is the capacity of node `n` in investment period `t_inv`. It is
      introduced in addition to `cap_inst` to simplify the model design.
    - `**prefix**_add` are the additions in the installed capacity of node `n` in investment
      period `t_inv`. Capacity additions are occurring at the beginning of an investment period.
    - `**prefix**_rem` are the reduction in the installed capacity of node `n` in investment
      period `t_inv`. Capacity reductions are occurring at the end of an investment period.
    - `**prefix**_invest_b` is an auxiliary variable used in some investment modes for the
      additions in capacities.
    - `**prefix**_remove_b` is an auxiliary variable used in some investment modes for the
      reduction of capacities.
"""
function EMB.variables_ext_data(
    m,
    _::Type{SingleInvData},
    𝒩ᴵⁿᵛ::Vector{<:EMB.Node},
    𝒯,
    𝒫,
    modeltype::AbstractInvestmentModel,
)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add investment variables for nodes for each strategic period
    @variable(m, cap_capex[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_current[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_add[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_rem[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_invest_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, cap_remove_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
end
function EMB.variables_ext_data(
    m,
    _::Type{StorageInvData},
    𝒩ˢᵗᵒʳ::Vector{<:EMB.Node},
    𝒯,
    𝒫,
    modeltype::EnergyModel,
)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add investment variables for storage nodes for each strategic period
    𝒩ˡᵉᵛᵉˡ = filter(n -> has_investment(n, :level), 𝒩ˢᵗᵒʳ)
    @variable(m, stor_level_capex[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_level_current[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_level_add[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_level_rem[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_level_invest_b[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, stor_level_remove_b[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)

    𝒩ᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :charge), 𝒩ˢᵗᵒʳ)
    @variable(m, stor_charge_capex[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_charge_current[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_charge_add[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_charge_rem[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, stor_charge_invest_b[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, stor_charge_remove_b[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)

    𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :discharge), 𝒩ˢᵗᵒʳ)
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
function EMB.variables_ext_data(
    m,
    _::Type{SingleInvData},
    ℒᴵⁿᵛ::Vector{<:Link},
    𝒯,
    𝒫,
    modeltype::EnergyModel
)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add investment variables for links for each strategic period
    @variable(m, link_cap_capex[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, link_cap_current[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, link_cap_add[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, link_cap_rem[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, link_cap_invest_b[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, link_cap_remove_b[ℒᴵⁿᵛ, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
end

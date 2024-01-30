"""
    constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::DataEmissions)

Constraints functions for calculating both the emissions and amount of CO₂ captured in the
process.

There exist several configurations:
- **`EmissionsEnergy`**: Only energy usage related emissions.\n
- **`EmissionsProcess`**: Both process and energy usage related emissions.\n
- **`CaptureEnergyEmissions`**: Capture of energy usage related emissions, can include \
process emissions.\n
- **`CaptureProcessEmissions`**: Capture of process emissions.\n
- **`CaptureProcessEnergyEmissions`**: Capture of both process and energy usage related
emissions.\n
"""
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsEnergy)

    # Declaration of the required subsets.
    𝒫ⁱⁿ = inputs(n)
    CO2 = co2_instance(modeltype)
    𝒫ᵉᵐ = setdiff(res_em(𝒫), [CO2])

    # Constraint for the CO2 emissions
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:emissions_node][n, t, CO2] ==
        sum(co2_int(p) * m[:flow_in][n, t, p] for p ∈ 𝒫ⁱⁿ)
    )

    # Constraint for the other emissions to avoid problems with unconstrained variables
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ], m[:emissions_node][n, t, p_em] == 0)
end
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::EmissionsProcess)

    # Declaration of the required subsets.
    𝒫ⁱⁿ = inputs(n)
    CO2 = co2_instance(modeltype)
    𝒫ᵉᵐ = setdiff(res_em(𝒫), [CO2])

    # Constraint for the CO2 emissions
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:emissions_node][n, t, CO2] ==
        m[:cap_use][n, t] * process_emissions(data, CO2, t) +
        sum(co2_int(p) * m[:flow_in][n, t, p] for p ∈ 𝒫ⁱⁿ)
    )

    # Constraint for the other emissions based on the provided process emissions
    @constraint(
        m,
        [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * process_emissions(data, p_em, t)
    )
end
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureEnergyEmissions)

    # Declaration of the required subsets.
    𝒫ⁱⁿ = inputs(n)
    CO2 = co2_instance(modeltype)
    𝒫ᵉᵐ = setdiff(res_em(𝒫), [CO2])

    # Calculate the total amount of CO2 to be considered for capture
    CO2_tot = @expression(m, [t ∈ 𝒯], sum(co2_int(p) * m[:flow_in][n, t, p] for p ∈ 𝒫ⁱⁿ))

    # Constraint for the CO2 emissions
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:emissions_node][n, t, CO2] ==
        (1 - co2_capture(data)) * CO2_tot[t] +
        m[:cap_use][n, t] * process_emissions(data, CO2, t)
    )

    # Constraint for the other emissions to avoid problems with unconstrained variables.
    @constraint(
        m,
        [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * process_emissions(data, p_em, t)
    )

    # Constraint for the outlet of the CO2
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, CO2] == CO2_tot[t] * co2_capture(data))
end
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureProcessEmissions)

    # Declaration of the required subsets.
    𝒫ⁱⁿ = inputs(n)
    CO2 = co2_instance(modeltype)
    𝒫ᵉᵐ = setdiff(res_em(𝒫), [CO2])

    # Calculate the total amount of CO2 to be considered for capture
    CO2_tot = @expression(m, [t ∈ 𝒯], m[:cap_use][n, t] * process_emissions(data, CO2, t))

    # Constraint for the CO2 emissions
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:emissions_node][n, t, CO2] ==
        (1 - co2_capture(data)) * CO2_tot[t] + sum(co2_int(p) * m[:flow_in][n, t, p] for p ∈ 𝒫ⁱⁿ)
    )

    # Constraint for the other emissions to avoid problems with unconstrained variables.
    @constraint(
        m,
        [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * process_emissions(data, p_em, t)
    )

    # Constraint for the outlet of the CO2
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, CO2] == CO2_tot[t] * co2_capture(data))
end
function constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::CaptureProcessEnergyEmissions)

    # Declaration of the required subsets
    𝒫ⁱⁿ = inputs(n)
    CO2 = co2_instance(modeltype)
    𝒫ᵉᵐ = setdiff(res_em(𝒫), [CO2])

    # Calculate the total amount of CO2 to be considered for capture
    CO2_tot = @expression(
        m,
        [t ∈ 𝒯],
        m[:cap_use][n, t] * process_emissions(data, CO2, t) +
        sum(co2_int(p) * m[:flow_in][n, t, p] for p ∈ 𝒫ⁱⁿ)
    )

    # Constraint for the CO2 emissions
    @constraint(
        m,
        [t ∈ 𝒯],
        m[:emissions_node][n, t, CO2] == (1 - co2_capture(data)) * CO2_tot[t]
    )

    # Constraint for the other emissions to avoid problems with unconstrained variables.
    @constraint(
        m,
        [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * process_emissions(data, p_em, t)
    )

    # Constraint for the outlet of the CO2
    @constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, CO2] == CO2_tot[t] * co2_capture(data))
end

"""
    constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::Data)

Fallback option when data is specified, but it is not desired to add the constraints through
this function. This is, e.g., the case for `EnergyModelsInvestments` as the capacity
constraint has to be replaced
"""
constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::Data) = nothing

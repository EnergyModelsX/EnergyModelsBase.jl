"""
    constraints_capacity(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum capacity of a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_capacity(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)

    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t]
    )

    constraints_capacity_installed(m, n, 𝒯, modeltype)
end

"""
    constraints_capacity(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum level of a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_capacity(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)

    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] <= m[:stor_cap_inst][n, t]
    )

    @constraint(m, [t ∈ 𝒯],
        m[:stor_rate_use][n, t] <= m[:stor_rate_inst][n, t]
    )

    constraints_capacity_installed(m, n, 𝒯, modeltype)
end

"""
    constraints_capacity(m, n::Sink, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the maximum capacity of a generic `Sink`.
This function serves as fallback option if no other function is specified for a `Sink`.
"""
function constraints_capacity(m, n::Sink, 𝒯::TimeStructure, modeltype::EnergyModel)

    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] + m[:sink_deficit][n,t] ==
            m[:cap_inst][n, t] + m[:sink_surplus][n,t]
    )

    constraints_capacity_installed(m, n, 𝒯, modeltype)
end

"""
    constraints_capacity_installed(m, n, 𝒯::TimeStructure, modeltype::EnergyModel)

In general, it is prefered to have the capacity as a function of a variable given with a
value of 1 in the field `n.Cap`.
"""
function constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)

    cap = capacity(n)
    @constraint(m, [t ∈ 𝒯],
        m[:cap_inst][n, t] == cap[t]
    )
end


function constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)

    cap = capacity(n)
    @constraint(m, [t ∈ 𝒯],
        m[:stor_cap_inst][n, t] == cap.level[t]
    )

    @constraint(m, [t ∈ 𝒯],
        m[:stor_rate_inst][n, t] == cap.rate[t]
    )
end

"""
    constraints_flow_in(m, n, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the inlet flow to a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_flow_in(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒫ⁱⁿ  = input(n)

    # Constraint for the individual input stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:flow_in][n, t, p] == m[:cap_use][n, t] * input(n, p)
    )


end

"""
    constraints_flow_in(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the inlet flow to a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_flow_in(m, n::Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    p_stor = storage_resource(n)
    𝒫ᵃᵈᵈ   = setdiff(input(n), [p_stor])

    # Constraint for additional required input
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵃᵈᵈ],
        m[:flow_in][n, t, p] == m[:flow_in][n, t, p_stor] * input(n, p)
    )

    # Constraint for storage rate use
    @constraint(m, [t ∈ 𝒯],
        m[:stor_rate_use][n, t] == m[:flow_in][n, t, p_stor]
    )


end


"""
    constraints_flow_out(m, n, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_flow_out(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒫ᵒᵘᵗ = output(n)

    # Constraint for the individual output stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:flow_out][n, t, p] == m[:cap_use][n, t] * output(n, p)
    )

end


"""
    constraints_opex_fixed(m, n::Node, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the fixed OPEX of a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_opex_fixed(m, n::Node, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] ==
            opex_fixed(n, t_inv) * m[:cap_inst][n, first(t_inv)]
    )
end

"""
    constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the fixed OPEX of a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] ==
            opex_fixed(n, t_inv) * m[:stor_cap_inst][n, first(t_inv)]
    )
end

"""
    constraints_opex_fixed(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the fixed OPEX of a generic `Sink`.
This function serves as fallback option if no other function is specified for a `Sink`.
"""
function constraints_opex_fixed(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] == 0
    )
end


"""
    constraints_opex_var(m, n::Node, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_opex_var(m, n::Node, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] ==
            sum(m[:cap_use][n, t] * opex_var(n, t) * duration(t) for t ∈ t_inv)
    )
end

"""
    constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    p_stor = storage_resource(n)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] ==
            sum(m[:flow_in][n, t, p_stor] * opex_var(n, t) * duration(t) for t ∈ t_inv)
    )
end

"""
    constraints_opex_var(m, n::RefStorageEmissions, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `RefStorageEmissions`.
"""
function constraints_opex_var(m, n::RefStorageEmissions, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    p_stor = storage_resource(n)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] ==
            sum((m[:flow_in][n, t , p_stor] - m[:emissions_node][n, t, p_stor])
            * opex_var(n, t) * duration(t) for t ∈ t_inv)
    )
end

"""
    constraints_opex_var(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a generic `Sink`.
This function serves as fallback option if no other function is specified for a `Sink`.
"""
function constraints_opex_var(m, n::Sink, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] ==
            sum((m[:sink_surplus][n, t] * surplus(n, t)
               + m[:sink_deficit][n, t] * deficit(n, t))
               * duration(t) for t ∈ t_inv)
    )
end

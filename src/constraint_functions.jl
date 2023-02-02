"""
constraints_capacity(m, n::Node, 𝒯::TimeStructure)

Function for creating the constraint on the maximum capacity of a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_capacity(m, n::Node, 𝒯::TimeStructure)

    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t]
    )
end

"""
constraints_capacity(m, n::Storage, 𝒯::TimeStructure)

Function for creating the constraint on the maximum level of a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_capacity(m, n::Storage, 𝒯::TimeStructure)

    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] <= m[:stor_cap_inst][n, t]
    )

    @constraint(m, [t ∈ 𝒯],
        m[:stor_rate_use][n, t] <= m[:stor_rate_inst][n, t]
    )
end

"""
constraints_capacity(m, n::Sink, 𝒯::TimeStructure)

Function for creating the constraint on the maximum capacity of a generic `Sink`.
This function serves as fallback option if no other function is specified for a `Sink`.
"""
function constraints_capacity(m, n::Sink, 𝒯::TimeStructure)

    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] + m[:sink_deficit][n,t] == 
            m[:cap_inst][n, t] + m[:sink_surplus][n,t]
    )

end


"""
    constraints_flow_in(m, n, 𝒯::TimeStructure)

Function for creating the constraint on the inlet flow to a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_flow_in(m, n::Node, 𝒯::TimeStructure)
    # Declaration of the required subsets
    𝒫ⁱⁿ  = keys(n.Input)

    # Constraint for the individual input stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ], 
        m[:flow_in][n, t, p] == m[:cap_use][n, t] * n.Input[p]
    )


end

"""
    constraints_flow_in(m, n::Storage, 𝒯::TimeStructure)

Function for creating the constraint on the inlet flow to a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_flow_in(m, n::Storage, 𝒯::TimeStructure)
    # Declaration of the required subsets
    p_stor = n.Stor_res
    𝒫ᵃᵈᵈ   = setdiff(keys(n.Input), [p_stor])

    # Constraint for additional required input
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵃᵈᵈ], 
        m[:flow_in][n, t, p] == m[:flow_in][n, t, p_stor] * n.Input[p]
    )

    # Constraint for storage rate use
    @constraint(m, [t ∈ 𝒯],
        m[:stor_rate_use][n, t] == m[:flow_in][n, t, p_stor]
    )


end


"""
    constraints_flow_out(m, n, 𝒯::TimeStructure)

Function for creating the constraint on the outlet flow from a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_flow_out(m, n::Node, 𝒯::TimeStructure)
    # Declaration of the required subsets
    𝒫ᵒᵘᵗ = keys(n.Output)

    # Constraint for the individual output stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:flow_out][n, t, p] == m[:cap_use][n, t] * n.Output[p]
    )

end


"""
    constraints_opex_fixed(m, n::Node, 𝒯ᴵⁿᵛ)

Function for creating the constraint on the fixed OPEX of a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_opex_fixed(m, n::Node, 𝒯ᴵⁿᵛ)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] == 
            n.Opex_fixed[t_inv] * m[:cap_inst][n, first(t_inv)]
    )
end

"""
    constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ)

Function for creating the constraint on the fixed OPEX of a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] == 
            n.Opex_fixed[t_inv] * m[:stor_cap_inst][n, first(t_inv)]
    )
end

"""
    constraints_opex_fixed(m, n::Sink, 𝒯ᴵⁿᵛ)

Function for creating the constraint on the fixed OPEX of a generic `Sink`.
This function serves as fallback option if no other function is specified for a `Sink`.
"""
function constraints_opex_fixed(m, n::Sink, 𝒯ᴵⁿᵛ)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] == 0
    )
end


"""
    constraints_opex_var(m, n::Node, 𝒯ᴵⁿᵛ)

Function for creating the constraint on the variable OPEX of a generic `Node`.
This function serves as fallback option if no other function is specified for a `Node`.
"""
function constraints_opex_var(m, n::Node, 𝒯ᴵⁿᵛ)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv)
    )
end

"""
    constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ)

Function for creating the constraint on the variable OPEX of a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_opex_var(m, n::Storage, 𝒯ᴵⁿᵛ)
    
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum(m[:flow_in][n, t, n.Stor_res] * n.Opex_var[t] * t.duration for t ∈ t_inv)
    )
end

"""
    constraints_opex_var(m, n::RefStorageEmissions, 𝒯ᴵⁿᵛ)

Function for creating the constraint on the variable OPEX of a `RefStorageEmissions`.
"""
function constraints_opex_var(m, n::RefStorageEmissions, 𝒯ᴵⁿᵛ)
    
    p_stor = n.Stor_res
        
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum((m[:flow_in][n, t , p_stor] - m[:emissions_node][n, t, p_stor])
            * n.Opex_var[t] * t.duration for t ∈ t_inv)
    )
end

"""
    constraints_opex_var(m, n::Sink, 𝒯ᴵⁿᵛ)

Function for creating the constraint on the variable OPEX of a generic `Sink`.
This function serves as fallback option if no other function is specified for a `Sink`.
"""
function constraints_opex_var(m, n::Sink, 𝒯ᴵⁿᵛ)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum((m[:sink_surplus][n, t] * n.Penalty[:Surplus][t] 
               + m[:sink_deficit][n, t] * n.Penalty[:Deficit][t])
               * t.duration for t ∈ t_inv)
    )
end
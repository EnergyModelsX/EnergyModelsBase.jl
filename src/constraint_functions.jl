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
    𝒫ⁱⁿ  = inputs(n)

    # Constraint for the individual input stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:flow_in][n, t, p] == m[:cap_use][n, t] * inputs(n, p)
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
    𝒫ᵃᵈᵈ   = setdiff(inputs(n), [p_stor])

    # Constraint for additional required input
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵃᵈᵈ],
        m[:flow_in][n, t, p] == m[:flow_in][n, t, p_stor] * inputs(n, p)
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
    # Declaration of the required subsets, excluding CO2, if specified
    𝒫ᵒᵘᵗ = res_not(outputs(n), co2_instance(modeltype))

    # Constraint for the individual output stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:flow_out][n, t, p] == m[:cap_use][n, t] * outputs(n, p)
    )
end


"""
    constraints_level(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)

Function for creating the level constraint for a reference storage node with a
`ResourceCarrier` resource.
"""
function constraints_level(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ᴵⁿᵛ   = strategic_periods(𝒯)

    # Call the auxiliary function for additional constraints on the level
    constraints_level_aux(m, n, 𝒯, 𝒫, modeltype)

    # Mass/energy balance constraints for stored energy carrier.
    for t_inv ∈ 𝒯ᴵⁿᵛ
        constraints_level_sp(m, n, t_inv, 𝒫, modeltype)
    end
end


"""
    constraints_level_aux(m, n::RefStorage{S}, 𝒯, 𝒫, modeltype::EnergyModel) where {S<:ResourceCarrier}

Function for creating the Δ constraint for the level of a reference storage node with a
`ResourceCarrier` resource.
"""
function constraints_level_aux(m, n::RefStorage{S}, 𝒯, 𝒫, modeltype::EnergyModel) where {S<:ResourceCarrier}
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the change in the level in a given operational period
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] == m[:flow_in][n, t, p_stor] - m[:flow_out][n, t, p_stor]
    )
end

"""
    constraints_level_aux(m, n::RefStorage{S}, 𝒯, 𝒫, modeltype::EnergyModel) where {S<:ResourceEmit}

Function for creating the Δ constraint for the level of a reference storage node with a
`ResourceEmit` resource.
"""
function constraints_level_aux(m, n::RefStorage{S}, 𝒯, 𝒫, modeltype::EnergyModel) where {S<:ResourceEmit}
    # Declaration of the required subsets
    p_stor = storage_resource(n)
    𝒫ᵉᵐ    = setdiff(res_sub(𝒫, ResourceEmit), [p_stor])

    # Constraint for the change in the level in a given operational period
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] ==
            m[:flow_in][n, t, p_stor] - m[:emissions_node][n, t, p_stor]
    )

    # Constraint to avoid that the emissions are larger than the flow into the storage
    @constraint(m, [t ∈ 𝒯], m[:stor_level_Δ_op][n, t] ≥ 0)


    # Constraint for the emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ], m[:emissions_node][n, t, p_em] == 0)
end

"""
    constraints_level_sp(
        m,
        n::RefStorage{S},
        t_inv::TS.StrategicPeriod{T, U},
        𝒫,
        modeltype::EnergyModel
        ) where {S<:ResourceCarrier, T, U<:SimpleTimes}

Function for creating the level constraint for a reference storage node with a
`ResourceCarrier` resource when the operational `TimeStructure` is given as `SimpleTimes`.
"""
function constraints_level_sp(
    m,
    n::RefStorage{S},
    t_inv::TS.StrategicPeriod{T, U},
    𝒫,
    modeltype::EnergyModel
    ) where {S<:ResourceCarrier, T, U<:SimpleTimes}

    # Mass/energy balance constraints for stored energy carrier.
    for (t_prev, t) ∈ withprev(t_inv)
        if isnothing(t_prev)
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, last(t_inv)] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )
        else
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, t_prev] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )
        end
    end
end

"""
    constraints_level_sp(
        m,
        n::RefStorage{S},
        t_inv::TS.StrategicPeriod{T, RepresentativePeriods{U, T, SimpleTimes{T}}},
        𝒫,
        modeltype::EnergyModel
        ) where {S<:ResourceCarrier, T, U}

Function for creating the level constraint for a reference storage node with a
`ResourceCarrier` resource when the operational `TimeStructure` is given as
`RepresentativePeriods`.
"""
function constraints_level_sp(
    m,
    n::RefStorage{S},
    t_inv::TS.StrategicPeriod{T, RepresentativePeriods{U, T, SimpleTimes{T}}},
    𝒫,
    modeltype::EnergyModel
    ) where {S<:ResourceCarrier, T, U}

    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(t_inv)

    # Constraint for the total change in the level in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:stor_level_Δ_rp][n, t_rp] ==
            sum(m[:stor_level_Δ_op][n, t] * multiple_strat(t_inv, t) * duration(t) for t ∈ t_rp)
    )

    # Constraint that the total change has to be 0
    @constraint(m, sum(m[:stor_level_Δ_rp][n, t_rp] for t_rp ∈ 𝒯ʳᵖ) == 0)

    # Mass/energy balance constraints for stored energy carrier.
    for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
        if isnothing(t_rp_prev) && isnothing(t_prev)

            # Last representative period in t_inv
            t_rp_last = last(𝒯ʳᵖ)

            # Constraint for the level of the first operational period in the first
            # representative period in a strategic period
            # The substraction of stor_level_Δ_op[n, first(t_rp_last)] is necessary to avoid
            # treating the first operational period differently with respect to the level
            # as the latter is at the end of the period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, first(t_rp_last)] -
                    m[:stor_level_Δ_op][n, first(t_rp_last)] * duration(first(t_rp_last)) +
                    m[:stor_level_Δ_rp][n, t_rp_last] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )

            # Constraint to avoid starting below 0 in this operational period
            @constraint(m,
                m[:stor_level][n, t] -
                m[:stor_level_Δ_op][n, t] * duration(t) ≥ 0
            )

            # Constraint to avoid having a level larger than the storage allows
            @constraint(m,
                m[:stor_level][n, t] -
                m[:stor_level_Δ_op][n, t] * duration(t) ≤ m[:stor_cap_inst][n, t]
            )

        elseif isnothing(t_prev)
            # Constraint for the level of the first operational period in any following
            # representative period
            # The substraction of stor_level_Δ_op[n, first(t_rp_prev)] is necessary to avoid
            # treating the first operational period differently with respect to the level
            # as the latter is at the end of the period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, first(t_rp_prev)] -
                    m[:stor_level_Δ_op][n, first(t_rp_prev)] * duration(first(t_rp_prev)) +
                    m[:stor_level_Δ_rp][n, t_rp_prev] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )

            # Constraint to avoid starting below 0 in this operational period
            @constraint(m,
                m[:stor_level][n, t] -
                m[:stor_level_Δ_op][n, t] * duration(t) ≥ 0
            )
            # Constraint to avoid having a level larger than the storage allows
            @constraint(m,
                m[:stor_level][n, t] -
                m[:stor_level_Δ_op][n, t] * duration(t) ≤ m[:stor_cap_inst][n, t]
            )
        else
            # Constraint for the level of a standard operational period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, t_prev] + m[:stor_level_Δ_op][n, t] * duration(t)
            )
        end
    end
end

"""
    constraints_level_sp(
        m,
        n::RefStorage{S},
        t_inv::TS.StrategicPeriod{T, U},
        𝒫,
        modeltype::EnergyModel
        ) where {S<:ResourceEmit, T, U<:SimpleTimes}

Function for creating the level constraint for a reference storage node with a
`ResourceEmit` resource when the operational TimeStructure is given as `SimpleTimes`.
"""
function constraints_level_sp(
    m,
    n::RefStorage{S},
    t_inv::TS.StrategicPeriod{T, U},
    𝒫,
    modeltype::EnergyModel
    ) where {S<:ResourceEmit, T, U<:SimpleTimes}

    # Mass/energy balance constraints for stored energy carrier.
    for (t_prev, t) ∈ withprev(t_inv)
        if isnothing(t_prev)
            @constraint(m,
                m[:stor_level][n, t] ==
                m[:stor_level_Δ_op][n, t] * duration(t)
            )
        else
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, t_prev] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )
        end
    end
end

"""
    constraints_level_sp(
        m,
        n::RefStorage{S},
        t_inv::TS.StrategicPeriod{T, RepresentativePeriods{U, T, SimpleTimes{T}}},
        𝒫,
        modeltype::EnergyModel
        ) where {S<:ResourceEmit, T, U}

Function for creating the level constraint for a reference storage node with a
`ResourceEmit` resource when the operational TimeStructure is given as
`RepresentativePeriods`.
"""
function constraints_level_sp(
    m,
    n::RefStorage{S},
    t_inv::TS.StrategicPeriod{T, RepresentativePeriods{U, T, SimpleTimes{T}}},
    𝒫,
    modeltype::EnergyModel
    ) where {S<:ResourceEmit, T, U}

    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(t_inv)

    # Constraint for the total change in the level in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:stor_level_Δ_rp][n, t_rp] ==
            sum(m[:stor_level_Δ_op][n, t] * multiple_strat(t_inv, t) * duration(t) for t ∈ t_rp)
    )

    # Mass/energy balance constraints for stored energy resource.
    for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
        if isnothing(t_rp_prev) && isnothing(t_prev)

            # Constraint for the level of the first operational period in the first
            # representative period in a strategic period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )

        elseif isnothing(t_prev)
            # Constraint for the level of the first operational period in any following
            # representative period
            # The substraction of stor_level_Δ_op[n, first(t_rp_prev)] is necessary to avoid
            # treating the first operational period differently with respect to the level
            # as the latter is at the end of the period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, first(t_rp_prev)] -
                    m[:stor_level_Δ_op][n, first(t_rp_prev)] * duration(first(t_rp_prev)) +
                    m[:stor_level_Δ_rp][n, t_rp_prev] +
                    m[:stor_level_Δ_op][n, t] * duration(t)
            )

            # Constraint to avoid starting below 0 in this operational period
            @constraint(m,
                m[:stor_level][n, t] -
                m[:stor_level_Δ_op][n, t] * duration(t) ≥ 0
            )

            # Constraint to avoid starting below 0 in this operational period
            @constraint(m,
                m[:stor_level][n, t] -
                m[:stor_level_Δ_op][n, t] * duration(t) ≤ m[:stor_cap_inst][n, t]
            )
        else
            # Constraint for the level of a standard operational period
            @constraint(m,
                m[:stor_level][n, t] ==
                    m[:stor_level][n, t_prev] + m[:stor_level_Δ_op][n, t] * duration(t)
            )
        end
    end
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
    constraints_opex_fixed(m, n::Storage, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the fixed OPEX of a generic `Storage`.
This function serves as fallback option if no other function is specified for a `Storage`.
"""
function constraints_opex_fixed(m, n::RefStorage{T}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel) where {T<:ResourceEmit}

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] ==
            opex_fixed(n, t_inv) * m[:stor_rate_inst][n, first(t_inv)]
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
            sum(m[:cap_use][n, t] *
            opex_var(n, t) * multiple(t_inv, t)
        for t ∈ t_inv)
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
            sum(m[:flow_in][n, t, p_stor] * opex_var(n, t) * multiple(t_inv, t)
            for t ∈ t_inv)
    )
end

"""
    constraints_opex_var(m, n::RefStorage{T}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel) where {T<:ResourceEmit}

Function for creating the constraint on the variable OPEX of a `RefStorage{ResourceEmit}`.
"""
function constraints_opex_var(m, n::RefStorage{T}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel) where {T<:ResourceEmit}

    p_stor = storage_resource(n)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] ==
            sum((m[:flow_in][n, t , p_stor] - m[:emissions_node][n, t, p_stor]) *
                opex_var(n, t) * multiple(t_inv, t)
            for t ∈ t_inv)
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
            sum((m[:sink_surplus][n, t] * surplus_penalty(n, t) +
                 m[:sink_deficit][n, t] * deficit_penalty(n, t)) *
                multiple(t_inv, t)
            for t ∈ t_inv)
    )
end

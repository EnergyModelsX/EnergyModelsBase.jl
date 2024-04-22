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

Function for limiting the the installed capacity to the available capacity.

This function should only be used to dispatch on the modeltype for providing investments.
If you create new capacity variables, it is beneficial to include as well a method for this
function and the corresponding node types.
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
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        # Creation of the iterator and call of the iterator function -
        # The representative period is initiated with the current investment period to allows
        # for dispatching on it.
        prev_pers = PreviousPeriods(t_inv_prev, nothing,  nothing);
        cyclic_pers = CyclicPeriods(t_inv, t_inv)
        ts = t_inv.operational
        constraints_level_iterate(m, n, prev_pers, cyclic_pers, t_inv, ts, modeltype)
    end
end


"""
    constraints_level_aux(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)

Function for creating the Δ constraint for the level of a reference storage node with a
`ResourceCarrier` resource.
"""
function constraints_level_aux(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets
    p_stor = storage_resource(n)

    # Constraint for the change in the level in a given operational period
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level_Δ_op][n, t] == m[:flow_in][n, t, p_stor] - m[:flow_out][n, t, p_stor]
    )
end

"""
    constraints_level_aux(m, n::RefStorage{S}, 𝒯, 𝒫, modeltype::EnergyModel)

Function for creating the Δ constraint for the level of a reference storage node with a
`ResourceEmit` resource.
"""
function constraints_level_aux(m, n::RefStorage{AccumulatingEmissions}, 𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets
    p_stor = storage_resource(n)
    𝒫ᵉᵐ    = setdiff(res_sub(𝒫, ResourceEmit), [p_stor])

    # Set the lower bound for the emissions in the storage node
    for t ∈ 𝒯
        set_lower_bound(m[:emissions_node][n, t, p_stor], 0)
    end

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
    constraints_level_iterate(
        m,
        n::Storage,
        prev_pers::PreviousPeriods,
        cyclic_pers::CyclicPeriods,
        per,
        ts::RepresentativePeriods,
        modeltype::EnergyModel,
    )

Iterate through the individual time structures of a `Storage` node. This iteration function
should in general allow for all necessary functionality for incorporating modifications.

In the case of `RepresentativePeriods`, this is achieved through calling the function
[`constraints_level_rp`](@ref) to introduce, _e.g._, cyclic constraints as it is in the
default case.
 """
function constraints_level_iterate(
    m,
    n::Storage,
    prev_pers::PreviousPeriods,
    cyclic_pers::CyclicPeriods,
    per,
    _::RepresentativePeriods,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(per)
    last_rp = last(𝒯ʳᵖ)

    # Constraint for additional, node specific constraints for representative periods
    constraints_level_rp(m, n, per, modeltype)

    # Constraint for the total change in the level in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:stor_level_Δ_rp][n, t_rp] ==
            sum(m[:stor_level_Δ_op][n, t] * multiple_strat(per, t) * duration(t) for t ∈ t_rp)
    )

    # Iterate through the operational structure
    for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ)
        prev_pers = PreviousPeriods(strat_per(prev_pers), t_rp_prev, op_per(prev_pers));
        cyclic_pers = CyclicPeriods(last_rp, t_rp)
        ts = t_rp.operational.operational
        constraints_level_iterate(m, n, prev_pers, cyclic_pers, t_rp, ts, modeltype)
    end
end
"""
    constraints_level_iterate(
        m,
        n::Storage,
        prev_pers::PreviousPeriods,
        per,
        ts::OperationalScenarios,
        modeltype::EnergyModel,
    )

In the case of `OperationalScenarios`, this is achieved through calling the function
[`constraints_level_scp`](@ref). In the default case, no constraints are added.
"""
function constraints_level_iterate(
    m,
    n::Storage,
    prev_pers::PreviousPeriods,
    cyclic_pers::CyclicPeriods,
    per,
    _::OperationalScenarios,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ˢᶜ = opscenarios(per)

    # Constraint for additional, node specific constraints for scenario periods
    constraints_level_scp(m, n, per, modeltype)

    # Iterate through the operational structure
    for t_scp ∈ 𝒯ˢᶜ
        ts = t_scp.operational.operational
        constraints_level_iterate(m, n, prev_pers, cyclic_pers, t_scp, ts, modeltype)
    end
end

"""
    constraints_level_iterate(
        m,
        n::Storage,
        prev_pers::PreviousPeriods,
        per,
        ts::SimpleTimes,
        modeltype::EnergyModel,
    )

In the case of `SimpleTimes`, the iterator function is at its lowest level. In this
situation,the previous level is calculated using the function [`previous_level`](@ref) and
used for the storage balance. The the approach for calculating the  `previous_level` is
depending on the types in the parameteric type `PreviousPeriods`.

In addition, additional bounds can be included on the initial level within an operational
period.
"""
function constraints_level_iterate(
    m,
    n::Storage,
    prev_pers::PreviousPeriods,
    cyclic_pers::CyclicPeriods,
    per,
    _::SimpleTimes,
    modeltype::EnergyModel,
)

    # Iterate through the operational structure
    for (t_prev, t) ∈ withprev(per)
        prev_pers = PreviousPeriods(strat_per(prev_pers), rep_per(prev_pers), t_prev);

        # Extract the previous level
        prev_level = previous_level(m, n, prev_pers, cyclic_pers, modeltype)

        # Mass balance constraint in the storage
        @constraint(
            m,
            m[:stor_level][n, t] == prev_level + m[:stor_level_Δ_op][n, t] * duration(t)
        )

        # Constraint for avoiding starting below 0 if the previous operational level is
        # nothing
        constraints_level_bounds(m, n, t, cyclic_pers, modeltype)
    end
end

"""
    constraints_level_rp(m, n::Storage, per, modeltype::EnergyModel)

Provides additional contraints for representative periods.

The default approach is to set the total change in all representative periods within a
strategic period to 0. This implies that the `Storage` node cannot accumulate energy between
individual strategic periods.
"""
function constraints_level_rp(m, n::Storage, per, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(per)

    # Constraint that the total change has to be 0 within a strategic period
    @constraint(m, sum(m[:stor_level_Δ_rp][n, t_rp] for t_rp ∈ 𝒯ʳᵖ) == 0)
end
"""
    constraints_level_rp(m, n::Storage{<:Accumulating}, per, modeltype::EnergyModel)

When a `Storage{<:Accumulating}` is used, the cyclic constraint is not implemented as
accumulation within a strategic period is desirable.
"""
function constraints_level_rp(m, n::Storage{<:Accumulating}, per, modeltype::EnergyModel)
    return nothing
end
"""
    constraints_level_rp(m, n::Storage{CyclicRepresentative}, per, modeltype::EnergyModel)

When a `CyclicStorage` is used, the the change in the representative period
is constrained to 0.
"""
function constraints_level_rp(m, n::Storage{CyclicRepresentative}, per, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(per)

    # Constraint that the total change has to be 0 within a representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ], m[:stor_level_Δ_rp][n, t_rp] == 0)
end

"""
    constraints_level_scp(m, n::Storage, per, modeltype::EnergyModel)

Provides additional constraints for scenario periods.

The default approach is to not provide any constraints.
"""
function constraints_level_scp(m, n::Storage, per, modeltype::EnergyModel)
    return nothing
end

"""
    constraints_level_bounds(
        m,
        n::Storage,
        t::TS.TimePeriod,
        prev_pers::TS.TimePeriod,
        modeltype::EnergyModel,
    )

Provides bounds on the initial storage level in an operational period to account for the
level being modelled at the end of the operational periods.

The default approach is to not provide bounds.
"""
function constraints_level_bounds(
    m,
    n::Storage,
    t::TS.TimePeriod,
    cyclic_pers::CyclicPeriods{<:TS.AbstractStrategicPeriod},
    modeltype::EnergyModel,
)

    return nothing
end
"""
    constraints_level_bounds(
        m,
        n::Storage,
        t::TS.TimePeriod,
        cyclic_pers::CyclicPeriods{<:TS.AbstractRepresentativePeriod},
        modeltype::EnergyModel,
    )

When representative periods are used and the previous opeartional period is nothing, then
bounds are incorporated to avoid that the initial level storage level is violating the
maximum and minimum level.
"""
function constraints_level_bounds(
    m,
    n::Storage,
    t::TS.TimePeriod,
    cyclic_pers::CyclicPeriods{<:TS.AbstractRepresentativePeriod},
    modeltype::EnergyModel,
)

    # Constraint to avoid starting below 0 in this operational period
    @constraint(m,
        0 ≤
            m[:stor_level][n, t] - m[:stor_level_Δ_op][n, t] * duration(t)
    )

    # Constraint to avoid having a level larger than the storage allows
    @constraint(m,
        m[:stor_cap_inst][n, t] ≥
            m[:stor_level][n, t] - m[:stor_level_Δ_op][n, t] * duration(t)
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
    constraints_opex_fixed(m, n::RefStorage{AccumulatingEmissions}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the fixed OPEX of a `RefStorage{AccumulatingEmissions}`
node. In this case, the fixed OPEX are dependent on the installed storage rate and not the
installed level.
"""
function constraints_opex_fixed(m, n::RefStorage{AccumulatingEmissions}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

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
    constraints_opex_var(m, n::RefStorage{AccumulatingEmissions}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `RefStorage{ResourceEmit}`.
"""
function constraints_opex_var(m, n::Storage{AccumulatingEmissions}, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

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

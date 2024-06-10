"""
    EMB.constraints_capacity_installed(
        m,
        n::EMB.Node,
        𝒯::TimeStructure,
        modeltype::AbstractInvestmentModel,
    )

When the modeltype is an investment model, the function introduces the related constraints
for the capacity expansion. The investment mode and lifetime mode are used for adding
constraints.

The default function only accepts nodes with [`SingleInvData`](@ref). If you have several
capacities for investments, you have to dispatch specifically on the node type. This is
implemented for `Storage` nodes.
"""
function EMB.constraints_capacity_installed(
    m,
    n::EMB.Node,
    𝒯::TimeStructure,
    modeltype::AbstractInvestmentModel,
)

    if EMI.has_investment(n)
        # Extract the investment data, the discount rate, and the strategic periods
        disc_rate = EMI.discount_rate(modeltype)
        inv_data = EMI.investment_data(n, :cap)
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Add the investment constraints
        EMI.add_investment_constraints(m, n, inv_data, :cap, :cap, 𝒯ᴵⁿᵛ, disc_rate)
    else
        for t ∈ 𝒯
            fix(m[:cap_inst][n, t], EMB.capacity(n, t); force=true)
        end
    end
end

"""
    EMB.constraints_capacity_installed(
        m,
        n::Storages,
        𝒯::TimeStructure,
        modeltype::AbstractInvestmentModel,
    )

When the modeltype is an investment model and the node is a `Storage` node, the function
introduces the related constraints for the capacity expansions for the fields `:charge`,
`:level`, and `:discharge`. This requires the utilization of the [`StorageInvData`](@ref)
investment type, in which the investment mode and lifetime mode are used for adding
constraints for each capacity.
"""
function EMB.constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::AbstractInvestmentModel)
    # Extract the he discount rate and the strategic periods
    disc_rate = EMI.discount_rate(modeltype)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    cap_fields = [:charge, :level, :discharge]

    for cap ∈ cap_fields
        if !hasfield(typeof(n), cap)
            continue
        end
        stor_par = getfield(n, cap)
        prefix = Symbol(:stor_, cap)
        var_inst = EMI.get_var_inst(m, prefix, n)
        if EMI.has_investment(n, cap)
            # Extract the investment data
            inv_data = EMI.investment_data(n, cap)

            # Add the investment constraints
            EMI.add_investment_constraints(m, n, inv_data, cap, prefix, 𝒯ᴵⁿᵛ, disc_rate)

        elseif isa(stor_par, EMB.UnionCapacity)
            for t ∈ 𝒯
                fix(var_inst[t], capacity(stor_par, t); force=true)
            end
        end
    end
end
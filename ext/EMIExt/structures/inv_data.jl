"""
    StorageInvData <: EMB.StorageInvData

Internal type for [`StorageInvData`](@ref EMB.StorageInvData). The introduction of an
internal type is necessary as extensions do not allow to export functions or types.
"""
struct StorageInvData <: EMB.StorageInvData
    charge::Union{AbstractInvData,Nothing}
    level::Union{AbstractInvData,Nothing}
    discharge::Union{AbstractInvData,Nothing}
    function StorageInvData(; charge = nothing, level = nothing, discharge = nothing)
        return new(charge, level, discharge)
    end
end
EMB.StorageInvData(; args...) = StorageInvData(; args...)

"""
    SingleInvData <: EMB.SingleInvData

Internal type for [`SingleInvData`](@ref EMB.SingleInvData). The introduction of an internal
type is necessary as extensions do not allow to export functions or types.
"""
struct SingleInvData <: EMB.SingleInvData
    cap::AbstractInvData
    function SingleInvData(cap)
        return new(cap)
    end
end
EMB.SingleInvData(args...) = SingleInvData(args...)
function EMB.SingleInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    inv_mode::Investment,
)
    return SingleInvData(NoStartInvData(capex_trans, trans_max_inst, inv_mode))
end
function EMB.SingleInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    inv_mode::Investment,
    life_mode::LifetimeMode,
)
    return SingleInvData(NoStartInvData(capex_trans, trans_max_inst, inv_mode, life_mode))
end
function EMB.SingleInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    initial::TimeProfile,
    inv_mode::Investment,
)
    return SingleInvData(StartInvData(capex_trans, trans_max_inst, initial, inv_mode))
end
function EMB.SingleInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    initial::TimeProfile,
    inv_mode::Investment,
    life_mode::LifetimeMode,
)
    return SingleInvData(
        StartInvData(capex_trans, trans_max_inst, initial, inv_mode, life_mode),
    )
end

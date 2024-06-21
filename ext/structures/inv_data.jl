"""
    StorageInvData <: InvestmentData

Extra investment data for storage investments. The extra investment data for storage
investments can, but does not require investment data for the charge capacity of the storage
(**`charge`**), increasing the storage capacity (**`level`**), or the discharge capacity of
the storage (**`discharge`**).

It uses the macro `@kwdef` to use keyword arguments and default values.
Hence, the names of the parameters have to be specified.

# Fields
- **`charge::Union{AbstractInvData, Nothing}`** is the investment data for the charge capacity.
- **`level::Union{AbstractInvData, Nothing}`** is the investment data for the level capacity.
- **`discharge::Union{AbstractInvData, Nothing}`** is the investment data for the
  discharge capacity.
"""
struct StorageInvData <: InvestmentData
    charge::Union{AbstractInvData,Nothing}
    level::Union{AbstractInvData,Nothing}
    discharge::Union{AbstractInvData,Nothing}
    function StorageInvData(; charge = nothing, level = nothing, discharge = nothing)
        return new(charge, level, discharge)
    end
end
EMB.StorageInvData(; args...) = StorageInvData(; args...)

"""
    SingleInvData <: InvestmentData

Extra investment data for type investments. The extra investment data has only a single
field in which [`AbstractInvData`](@ref) has to be added.

The advantage of separating `AbstractInvData` from the `InvestmentData` node is to allow
easier separation of `EnergyModelsInvestments` and `EnergyModelsBase` and provides the user
with the potential of introducing new capacities for types.

# Fields
- **`cap::AbstractInvData`** is the investment data for the capacity.

When multiple inputs are provided, a constructor directly creates the corresponding
`AbstractInvData`.

# Fields
- **`capex::TimeProfile`** is the capital costs for investing in a capacity. The value is
  relative to the added capacity.
- **`max_inst::TimeProfile`** is the maximum installed capacity in a strategic period.
- **`initial::Real`** is the initial capacity. This results in the creation of a
  [`SingleInvData`](@ref) type for the investment data.
- **`inv_mode::Investment`** is the chosen investment mode for the technology. The following
  investment modes are currently available: [`BinaryInvestment`](@ref),
  [`DiscreteInvestment`](@ref), [`ContinuousInvestment`](@ref), [`SemiContinuousInvestment`](@ref)
  or [`FixedInvestment`](@ref).
- **`life_mode::LifetimeMode`** is type of handling the lifetime. Several different
  alternatives can be used: [`UnlimitedLife`](@ref), [`StudyLife`](@ref), [`PeriodLife`](@ref)
  or [`RollingLife`](@ref). If `life_mode` is not specified, the model assumes an
  [`UnlimitedLife`](@ref).
"""
struct SingleInvData <: InvestmentData
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
    initial::Real,
    inv_mode::Investment,
)
    return SingleInvData(StartInvData(capex_trans, trans_max_inst, initial, inv_mode))
end
function EMB.SingleInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    initial::Real,
    inv_mode::Investment,
    life_mode::LifetimeMode,
)
    return SingleInvData(
        StartInvData(capex_trans, trans_max_inst, initial, inv_mode, life_mode),
    )
end

"""
    EMB.InvData(;kwargs)

Internal method for [`InvData`](@ref EMB.InvData). The introduction of an internal method
is necessary as extensions do not allow to export functions or types.
"""
function EMB.InvData(;
    capex_cap::TimeProfile,
    cap_max_inst::TimeProfile,
    cap_max_add::TimeProfile,
    cap_min_add::TimeProfile,
    inv_mode::Investment = ContinuousInvestment(),
    cap_start::Union{Real,Nothing} = nothing,
    cap_increment::TimeProfile = FixedProfile(0),
    life_mode::LifetimeMode = UnlimitedLife(),
    lifetime::TimeProfile = FixedProfile(0),
)

    # Create the new investment mode structures
    if isa(inv_mode, BinaryInvestment)
        @error(
            "BinaryInvestment() cannot use the constructor as it is not possible to " *
            "deduce the capacity for the investment. You have to instead use the new " *
            "types as outlined in the documentation (https://energymodelsx.github.io/EnergyModelsInvestments.jl/how-to/update-models)"
        )
        return
    elseif isa(inv_mode, FixedInvestment)
        @error(
            "FixedInvestment() cannot use the constructor as it is not possible to " *
            "deduce the capacity for the investment. You have to instead use the new " *
            "types as outlined in the documentation (https://energymodelsx.github.io/EnergyModelsInvestments.jl/how-to/update-models)"
        )
        return
    elseif isa(inv_mode, DiscreteInvestment)
        tmp_inv_mode = DiscreteInvestment(cap_increment)
    elseif isa(inv_mode, ContinuousInvestment)
        tmp_inv_mode = ContinuousInvestment(cap_min_add, cap_max_add)
    elseif isa(inv_mode, SemiContinuousInvestment)
        tmp_inv_mode = SemiContinuousInvestment(cap_min_add, cap_max_add)
    end

    @warn(
        "The used implementation of a `InvData` will be discontinued in the near " *
        "future. See the documentation for the new implementation using the type " *
        "`SingleInvData` in the section on _How to update your model to the latest versions_.\n" *
        "The core change is that we allow the individual parameters are moved to the " *
        "fields `inv_mode` and `life_mode`.\n",
        maxlog = 1
    )

    # Create the new lifetime mode structures
    if isa(life_mode, UnlimitedLife)
        tmp_life_mode = UnlimitedLife()
    elseif isa(life_mode, StudyLife)
        tmp_life_mode = StudyLife(lifetime)
    elseif isa(life_mode, PeriodLife)
        tmp_life_mode = PeriodLife(lifetime)
    elseif isa(life_mode, RollingLife)
        tmp_life_mode = RollingLife(lifetime)
    end

    # Create the new generalized investment data
    if isnothing(cap_start)
        return EMB.SingleInvData(capex_cap, cap_max_inst, tmp_inv_mode, tmp_life_mode)
    else
        return EMB.SingleInvData(
            capex_cap,
            cap_max_inst,
            cap_start,
            tmp_inv_mode,
            tmp_life_mode,
        )
    end
end

"""
    InvDataStorage(;kwargs)

Internal method for [`InvDataStorage`](@ref EMB.InvDataStorage). The introduction of an
internal method is necessary as extensions do not allow to export functions or types.
"""
function EMB.InvDataStorage(;
    #Investment data related to storage power
    capex_rate::TimeProfile,
    rate_max_inst::TimeProfile,
    rate_max_add::TimeProfile,
    rate_min_add::TimeProfile,
    capex_stor::TimeProfile,
    stor_max_inst::TimeProfile,
    stor_max_add::TimeProfile,
    stor_min_add::TimeProfile,
    inv_mode::Investment = ContinuousInvestment(),
    rate_start::Union{Real,Nothing} = nothing,
    stor_start::Union{Real,Nothing} = nothing,
    rate_increment::TimeProfile = FixedProfile(0),
    stor_increment::TimeProfile = FixedProfile(0),
    life_mode::LifetimeMode = UnlimitedLife(),
    lifetime::TimeProfile = FixedProfile(0),
)

    # Create the new investment mode structures
    if isa(inv_mode, BinaryInvestment)
        @error(
            "BinaryInvestment() cannot use the constructor as it is not possible to " *
            "deduce the capacity for the investment. You have to instead use the new " *
            "types as outlined in the documentation (https://energymodelsx.github.io/EnergyModelsInvestments.jl/how-to/update-models)"
        )
        return
    elseif isa(inv_mode, FixedInvestment)
        @error(
            "FixedInvestment() cannot use the constructor as it is not possible to " *
            "deduce the capacity for the investment. You have to instead use the new " *
            "types as outlined in the documentation (https://energymodelsx.github.io/EnergyModelsInvestments.jl/how-to/update-models)"
        )
        return
    elseif isa(inv_mode, DiscreteInvestment)
        inv_mode_rate = DiscreteInvestment(rate_increment)
        inv_mode_cap = DiscreteInvestment(stor_increment)
    elseif isa(inv_mode, ContinuousInvestment)
        inv_mode_rate = ContinuousInvestment(rate_min_add, rate_max_add)
        inv_mode_cap = ContinuousInvestment(stor_min_add, stor_max_add)
    elseif isa(inv_mode, SemiContinuousInvestment)
        inv_mode_rate = SemiContinuousInvestment(rate_min_add, rate_max_add)
        inv_mode_cap = SemiContinuousInvestment(stor_min_add, stor_max_add)
    end

    @warn(
        "The used implementation of a `InvDataStorage` will be discontinued in the near " *
        "future. See the documentation for the new implementation using the type " *
        "`StorageInvData` in the section on _How to update your model to the latest " *
        "versions_.\n" *
        "The core change is that we allow now for individual investments in `charge`, " *
        "`level`, as well `discharge` capacities.\n" *
        "This constructore should NOT be used for `HydroStor` or `PumpedHydroStor nodes " *
        "introduced in the package [EnergyModelsRenewableProducers]" *
        "(https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/library/public/#EnergyModelsRenewableProducers.HydroStor).",
        maxlog = 1
    )

    # Create the new lifetime mode structures
    if isa(life_mode, UnlimitedLife)
        tmp_life_mode = UnlimitedLife()
    elseif isa(life_mode, StudyLife)
        tmp_life_mode = StudyLife(lifetime)
    elseif isa(life_mode, PeriodLife)
        tmp_life_mode = PeriodLife(lifetime)
    elseif isa(life_mode, RollingLife)
        tmp_life_mode = RollingLife(lifetime)
    end

    # Create the new generalized investment data
    if isnothing(rate_start)
        charge_type =
            NoStartInvData(capex_rate, rate_max_inst, inv_mode_rate, tmp_life_mode)
    else
        charge_type = StartInvData(
            capex_rate,
            rate_max_inst,
            rate_start,
            inv_mode_rate,
            tmp_life_mode,
        )
    end
    if isnothing(stor_start)
        level_type = NoStartInvData(capex_stor, stor_max_inst, inv_mode_cap, tmp_life_mode)
    else
        level_type =
            StartInvData(capex_stor, stor_max_inst, stor_start, inv_mode_cap, tmp_life_mode)
    end

    return EMB.StorageInvData(charge = charge_type, level = level_type)
end

"""
When the field `cap` is not included, it is assumed that its value is `FixedProfile(0)`.
This behavior is only for allowing the legacy constructor to work, while it will be removed
in the near future.
"""
EMI.FixedInvestment() = EMI.FixedInvestment(FixedProfile(0))
"""
When the field `cap` is not included, it is assumed that its value is `FixedProfile(0)`.
This behavior is only for allowing the legacy constructor to work, while it will be removed
in the near future.
"""
EMI.BinaryInvestment() = EMI.BinaryInvestment(FixedProfile(0))
"""
When the field `increment` is not included, it is assumed that its value is `FixedProfile(0)`.
This behavior is only for allowing the legacy constructor to work, while it will be removed
in the near future.
"""
EMI.DiscreteInvestment() = EMI.DiscreteInvestment(FixedProfile(0))
"""
When the fields `min_add` and `max_add` are not included, it is assumed that their values
are `FixedProfile(0)`. This behavior is only for allowing the legacy constructor to work,
while it will be removed in the near future.
"""
EMI.ContinuousInvestment() = EMI.ContinuousInvestment(FixedProfile(0), FixedProfile(0))
"""
When the fields `min_add` and `max_add` are not included, it is assumed that their values
are `FixedProfile(0)`. This behavior is only for allowing the legacy constructor to work,
while it will be removed in the near future.
"""
EMI.SemiContinuousInvestment() =
    EMI.SemiContinuousInvestment(FixedProfile(0), FixedProfile(0))
"""
When the fields `min_add`, `max_add`, and `capex_offset` are not included, it is assumed
that their values are `FixedProfile(0)`. This behavior is only for allowing the legacy
constructor to work, while it will be removed in the near future.
"""
EMI.SemiContinuousOffsetInvestment() =
    EMI.SemiContinuousOffsetInvestment(FixedProfile(0), FixedProfile(0), FixedProfile(0))

"""
When the field `lifetime` is not included, it is assumed that its value is `FixedProfile(0)`.
This behavior is only for allowing the legacy constructor to work, while it will be removed
in the near future.
"""
EMI.StudyLife() = EMI.StudyLife(FixedProfile(0))
"""
When the field `lifetime` is not included, it is assumed that its value is `FixedProfile(0)`.
This behavior is only for allowing the legacy constructor to work, while it will be removed
in the near future.
"""
EMI.PeriodLife() = EMI.PeriodLife(FixedProfile(0))
"""
When the field `lifetime` is not included, it is assumed that its value is `FixedProfile(0)`.
This behavior is only for allowing the legacy constructor to work, while it will be removed
in the near future.
"""
EMI.RollingLife() = EMI.RollingLife(FixedProfile(0))

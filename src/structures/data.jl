""" Abstract type used to define concrete struct containing the package specific elements
to add to the composite type defined in this package."""
abstract type Data end
""" Empty composite type for `Data`"""
struct EmptyData <: Data end

"""
    EmissionsData{T} <: Data end

Abstract type for `EmissionsData` can be used to dispatch on different types of
capture configurations.

In general, the different types require the following input:
- **`emissions::Dict{ResourceEmit, T}`**: Emissions per unit produced. It allows for
  an input as `TimeProfile` or `Float64`.
- **`co2_capture::Float64`**: CO₂ capture rate.

# Types
- **`CaptureProcessEnergyEmissions`**: Capture both the process emissions and the
  energy usage related emissions.
- **`CaptureProcessEmissions`**: Capture the process emissions, but not the
  energy usage related emissions.
- **`CaptureEnergyEmissions`**: Capture the energy usage related emissions, but not the
  process emissions. Does not require `emissions` as input.
- **`EmissionsProcess`**: No capture, but process emissions are present.
  Does not require `co2_capture` as input, but will ignore it, if provided.
- **`EmissionsEnergy`**: No capture and no process emissions. Does not require
  `co2_capture` or `emissions` as input, but will ignore them, if provided.
"""

""" `EmissionsData` as supertype for all `Data` types for emissions."""
abstract type EmissionsData{T} <: Data end
""" `CaptureData` as supertype for all `EmissionsData` that include CO₂ capture."""
abstract type CaptureData{T} <: EmissionsData{T} end

"""
    CaptureProcessEnergyEmissions{T} <: CaptureData{T}

Capture both the process emissions and the energy usage related emissions.

# Fields
- **`emissions::Dict{ResourceEmit, T}`** are the process emissions per unit produced.
- **`co2_capture::Float64`** is the CO₂ capture rate.
"""
struct CaptureProcessEnergyEmissions{T} <: CaptureData{T}
    emissions::Dict{<:ResourceEmit,T}
    co2_capture::Float64
end

"""
    CaptureProcessEmissions{T} <: CaptureData{T}

Capture the process emissions, but not the energy usage related emissions.

# Fields
- **`emissions::Dict{ResourceEmit, T}`** are the process emissions per unit produced.
- **`co2_capture::Float64`** is the CO₂ capture rate.
"""
struct CaptureProcessEmissions{T} <: CaptureData{T}
    emissions::Dict{<:ResourceEmit,T}
    co2_capture::Float64
end

"""
    CaptureEnergyEmissions{T} <: CaptureData{T}

Capture the energy usage related emissions, but not the process emissions.
Does not require `emissions` as input, but can be supplied.

# Fields
- **`emissions::Dict{ResourceEmit, T}`** are the process emissions per unit produced.
- **`co2_capture::Float64`** is the CO₂ capture rate.
"""
struct CaptureEnergyEmissions{T} <: CaptureData{T}
    emissions::Dict{<:ResourceEmit,T}
    co2_capture::Float64
end
CaptureEnergyEmissions(co2_capture::Float64) =
    CaptureEnergyEmissions(Dict{ResourceEmit,Float64}(), co2_capture)

"""
    EmissionsProcess{T} <: EmissionsData{T}

No capture, but process emissions are present. Does not require `co2_capture` as input,
but accepts it and will ignore it, if provided.

# Fields
- **`emissions::Dict{ResourceEmit, T}`**: emissions per unit produced.
"""
struct EmissionsProcess{T} <: EmissionsData{T}
    emissions::Dict{<:ResourceEmit,T}
end
EmissionsProcess(emissions::Dict{<:ResourceEmit,T}, _) where {T} =
    EmissionsProcess(emissions)
EmissionsProcess() = EmissionsProcess(Dict{ResourceEmit,Float64}())

"""
    EmissionsEnergy{T} <: EmissionsData{T}

No capture, no process emissions are present. Does not require `co2_capture` or `emissions`
as input, but accepts it and will ignore it, if provided.
"""
struct EmissionsEnergy{T} <: EmissionsData{T} end
EmissionsEnergy(_, _) = EmissionsEnergy{Float64}()
EmissionsEnergy(_) = EmissionsEnergy{Float64}()
EmissionsEnergy() = EmissionsEnergy{Float64}()

"""
    co2_capture(data::CaptureData)

Returns the CO₂ capture rate of the `data`.
"""
co2_capture(data::CaptureData) = data.co2_capture

"""
    process_emissions(data::EmissionsData)

Returns the [`ResourceEmit`](@ref)s that have process emissions of the [`EmissionsData`](@ref).
"""
process_emissions(data::EmissionsData) = collect(keys(data.emissions))

"""
    process_emissions(data::EmissionsData{T}, p::ResourceEmit)

Returns the the process emissions of resource `p` in the `data` as `TimeProfile`.
If the process emissions are provided as `Float64`, it returns a `FixedProfile(x)`.
If there are no process emissions, it returns a `FixedProfile(0)`.
"""
process_emissions(data::EmissionsData{T}, p::ResourceEmit) where {T<:Float64} =
    haskey(data.emissions, p) ? FixedProfile(data.emissions[p]) : FixedProfile(0)
process_emissions(data::EmissionsData{T}, p::ResourceEmit) where {T<:TimeProfile} =
    haskey(data.emissions, p) ? data.emissions[p] : FixedProfile(0)
process_emissions(data::EmissionsEnergy{T}, p::ResourceEmit) where {T} =
    @error("The type `EmissionsEnergy` should not be used in combination with calling \
    the function `process_emissions`.")

"""
    process_emissions(data::EmissionsData{T}, p:ResourceEmit, t)
Returns the the process emissions of resource `p` in the `data` at operational period t.
If there are no process emissions, it returns a value of 0.
"""
process_emissions(data::EmissionsData{T}, p::ResourceEmit, t) where {T<:Float64} =
    haskey(data.emissions, p) ? data.emissions[p] : 0
process_emissions(data::EmissionsData{T}, p::ResourceEmit, t) where {T<:TimeProfile} =
    haskey(data.emissions, p) ? data.emissions[p][t] : 0
process_emissions(data::EmissionsEnergy{T}, p::ResourceEmit, t) where {T} =
    @error("The type `EmissionsEnergy` should not be used in combination with calling \
    the function `process_emissions`.")

"""
Abstract type for the extra data for investing in technologies.
"""
abstract type InvestmentData <: Data end

"""
    StorageInvData <: InvestmentData

Extra investment data for storage investments. The extra investment data for storage
investments can, but does not require investment data for the charge capacity of the storage
(**`charge`**), increasing the storage capacity (**`level`**), or the discharge capacity of
the storage (**`discharge`**).

It utilizes a constructor with keyword arguments for the individual parameters.
Hence, the names of the parameters have to be specified.

# Fields
- **`charge::Union{AbstractInvData, Nothing}`** is the investment data for the charge capacity.
- **`level::Union{AbstractInvData, Nothing}`** is the investment data for the level capacity.
- **`discharge::Union{AbstractInvData, Nothing}`** is the investment data for the
  discharge capacity.
"""
abstract type StorageInvData <: InvestmentData end

"""
    SingleInvData <: InvestmentData

Extra investment data for type investments. The extra investment data has only a single
field in which `AbstractInvData` has to be added.

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
  [`StartInvData`](@extref EnergyModelsInvestments.StartInvData) type for the investment data.
- **`inv_mode::Investment`** is the chosen investment mode for the technology. The following
  investment modes are currently available:
  [`BinaryInvestment`](@extref EnergyModelsInvestments),
  [`DiscreteInvestment`](@extref EnergyModelsInvestments),
  [`ContinuousInvestment`](@extref EnergyModelsInvestments),
  [`SemiContinuousInvestment`](@extref EnergyModelsInvestments), or
  [`FixedInvestment`](@extref EnergyModelsInvestments).
- **`life_mode::LifetimeMode`** is type of handling the lifetime. Several different
  alternatives can be used:
  [`UnlimitedLife`](@extref EnergyModelsInvestments),
  [`StudyLife`](@extref EnergyModelsInvestments),
  [`PeriodLife`](@extref EnergyModelsInvestments), or
  [`RollingLife`](@extref EnergyModelsInvestments). If `life_mode` is not specified, the
  model assumes an [`UnlimitedLife`](@extref EnergyModelsInvestments).
"""
abstract type SingleInvData <: InvestmentData end

"""
    InvData(;
        capex_cap::TimeProfile,
        cap_max_inst::TimeProfile,
        cap_max_add::TimeProfile,
        cap_min_add::TimeProfile,
        inv_mode::Investment = ContinuousInvestment(),
        cap_start::Union{Real, Nothing} = nothing,
        cap_increment::TimeProfile = FixedProfile(0),
        life_mode::LifetimeMode = UnlimitedLife(),
        lifetime::TimeProfile = FixedProfile(0),
    )

Legacy constructor for a `InvData`.

The new storage descriptions allows now for a reduction in functions which is used
to make `EnergModelsInvestments` less dependent on `EnergyModelsBase`.

The core changes to the existing structure is the move of the required parameters to the
type `Investment` (_e.g._, the minimum and maximum added capacity is only required
for investment modes that require these parameters) as well as moving the `lifetime` to the
type `LifetimeMode`, when required.

See the _[documentation](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/how-to/update-models)_
for further information regarding how you can translate your existing model to the new model.
"""
InvData(nothing) = nothing

"""
    InvDataStorage(;
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
        rate_start::Union{Real, Nothing} = nothing,
        stor_start::Union{Real, Nothing} = nothing,
        rate_increment::TimeProfile = FixedProfile(0),
        stor_increment::TimeProfile = FixedProfile(0),
        life_mode::LifetimeMode = UnlimitedLife(),
        lifetime::TimeProfile = FixedProfile(0),
    )

Storage descriptions were changed in EnergyModelsBase v0.7 resulting in the requirement for
rewriting the investment options for `Storage` nodes.

See the _[documentation](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/how-to/update-models)_
for further information regarding how you can translate your existing model to the new model.
"""
InvDataStorage(nothing) = nothing

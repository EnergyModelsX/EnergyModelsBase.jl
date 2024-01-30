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
- **`emissions::Dict{ResourceEmit, T}`**: Emissions per unit produced. It allows for \
an input as `TimeProfile` or `Float64`.\n
- **`co2_capture::Float64`**: CO₂ capture rate.\n

# Types
- **`CaptureProcessEnergyEmissions`**: Capture both the process emissions and the \
energy usage related emissions.\n
- **`CaptureProcessEmissions`**: Capture the process emissions, but not the \
energy usage related emissions.\n
- **`CaptureEnergyEmissions`**: Capture the energy usage related emissions, but not the \
process emissions. Does not require `emissions` as input.\n
- **`EmissionsProcess`**: No capture, but process emissions are present. \
Does not require `co2_capture` as input, but will ignore it, if provided.\n
- **`EmissionsEnergy`**: No capture and no process emissions. Does not require \
`co2_capture` or `emissions` as input, but will ignore them, if provided.\n
"""

""" `EmissionsData` as supertype for all `Data` types for emissions."""
abstract type EmissionsData{T} <: Data end
""" `CaptureData` as supertype for all `EmissionsData` that include CO₂ capture."""
abstract type CaptureData{T} <: EmissionsData{T} end

"""
Capture both the process emissions and the energy usage related emissions.

# Fields
- **`emissions::Dict{ResourceEmit, T}`**: emissions per unit produced.\n
- **`co2_capture::Float64`** is the CO₂ capture rate.
"""
struct CaptureProcessEnergyEmissions{T} <: CaptureData{T}
    emissions::Dict{<:ResourceEmit,T}
    co2_capture::Float64
end

"""
Capture the process emissions, but not the energy usage related emissions.

# Fields
- **`emissions::Dict{ResourceEmit, T}`**: emissions per unit produced.\n
- **`co2_capture::Float64`** is the CO₂ capture rate.
"""
struct CaptureProcessEmissions{T} <: CaptureData{T}
    emissions::Dict{<:ResourceEmit,T}
    co2_capture::Float64
end

"""
Capture the energy usage related emissions, but not the process emissions.
Does not require `emissions` as input, but can be supplied.

# Fields
- **`emissions::Dict{ResourceEmit, T}`**: emissions per unit produced.\n
- **`co2_capture::Float64`** is the CO₂ capture rate.
"""
struct CaptureEnergyEmissions{T} <: CaptureData{T}
    emissions::Dict{<:ResourceEmit,T}
    co2_capture::Float64
end
CaptureEnergyEmissions(co2_capture::Float64) =
    CaptureEnergyEmissions(Dict{ResourceEmit, Float64}(), co2_capture)

"""
No capture, but process emissions are present. Does not require `co2_capture` as input,
but accepts it and will ignore it, if provided.

# Fields
- **`emissions::Dict{ResourceEmit, T}`**: emissions per unit produced.\n
"""
struct EmissionsProcess{T} <: EmissionsData{T}
    emissions::Dict{<:ResourceEmit,T}
end
EmissionsProcess(emissions::Dict{<:ResourceEmit,T}, _) where {T} = EmissionsProcess(emissions)
EmissionsProcess() = EmissionsProcess(Dict{ResourceEmit, Float64}())

"""
No capture, no process emissions are present. Does not require `co2_capture` or `emissions`
as input, but accepts it and will ignore it, if provided.
"""
struct EmissionsEnergy{T} <: EmissionsData{T}
end
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
Returns the `ResourceEmit`s that have process emissions in the `data`.
"""
process_emissions(data::EmissionsData) = collect(keys(data.emissions))

"""
    process_emissions(data::EmissionsData{T}, p::ResourceEmit)
Returns the the process emissions of resource `p` in the `data` as `TimeProfile`.
If the process emissions are provided as `Float64`, it returns a FixedProfile(x).
If there are no process emissions, it returns a FixedProfile(0).
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

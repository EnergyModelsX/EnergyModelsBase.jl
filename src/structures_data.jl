""" Abstract type used to define concrete struct containing the package specific elements
to add to the composite type defined in this package."""
abstract type Data end
""" Empty composite type for `Data`"""
struct EmptyData <: Data end

"""
    EmissionsData <: Data end

Abstract type for `EmissionsData` can be used to dispatch on different type of
capture configurations.

In general, the different types require the following input:
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`co2_capture::Real`** is the CO2 capture rate.\n

# Types
- **`CaptureProcessEnergyEmissions`**: Capture both the process emissions and the energy usage \
related emissions.\n
- **`CaptureProcessEmissions`**: Capture the process emissions, but not the energy usage related \
emissions.\n
- **`CaptureEnergyEmissions`**: Capture the energy usage related emissions, but not the process \
emissions. Does not require `emissions` as input.\n
- **`EmissionsProcess`**: No capture, but process emissions are present. Does not require \
`co2_capture` as input, but will ignore it, if provided.\n
"""

""" `EmissionsData` as supertype for all `Data` types for emissions."""
abstract type EmissionsData <: Data end
""" `CaptureData` as supertype for all `EmissionsData` that include CO2 capture."""
abstract type CaptureData <: EmissionsData end

"""
Capture both the process emissions and the energy usage related emissions.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`co2_capture::Real`** is the CO2 capture rate.
"""
struct CaptureProcessEnergyEmissions <: CaptureData
    emissions::Dict{ResourceEmit,Real}
    co2_capture::Real
end

"""
Capture the process emissions, but not the energy usage related emissions.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`co2_capture::Real`** is the CO2 capture rate.
"""
struct CaptureProcessEmissions <: CaptureData
    emissions::Dict{ResourceEmit,Real}
    co2_capture::Real
end

"""
Capture the energy usage related emissions, but not the process emissions.
Does not require `emissions` as input, but can be supplied.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
- **`co2_capture::Real`** is the CO2 capture rate.
"""
struct CaptureEnergyEmissions <: CaptureData
    emissions::Dict{ResourceEmit,Real}
    co2_capture::Real
end
CaptureEnergyEmissions(co2_capture::Real) = CaptureEnergyEmissions(Dict(), co2_capture)

"""
No capture, but process emissions are present. Does not require `co2_capture` as input,
but accepts it and will ignore it, if provided.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
"""
struct EmissionsProcess <: EmissionsData
    emissions::Dict{ResourceEmit,Real}
end
EmissionsProcess(emissions::Dict{ResourceEmit,Real}, _) = EmissionsProcess(emissions)
EmissionsProcess() = EmissionsProcess(Dict())

"""
No capture, no process emissions are present. Does not require `co2_capture` or `emissions`
as input, but accepts it and will ignore it, if provided.

# Fields
- **`emissions::Dict{ResourceEmit, Real}`**: emissions per unit produced.\n
"""
struct EmissionsEnergy <: EmissionsData
end
EmissionsEnergy(_, _) = EmissionsEnergy()
EmissionsEnergy(_) = EmissionsEnergy()

"""
    co2_capture(data::CaptureData)
Returns the CO2 capture rate of the `data`.
"""
co2_capture(data::CaptureData) = data.co2_capture

"""
    process_emissions(data::EmissionsData)
Returns the `ResourceEmit`s that have process emissions in the `data`.
"""
process_emissions(data::EmissionsData) = collect(keys(data))


"""
    process_emissions(data::EmissionsData, p)
Returns the the process emissions of resource `p` in the `data`.
If there are no process emissions, it returns a value of 0.
"""
process_emissions(data::EmissionsData, p) = haskey(data.emissions, p) ? data.emissions[p] : 0

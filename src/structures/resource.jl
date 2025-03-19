"""
General resource supertype to be used for the declaration of subtypes.
"""
abstract type Resource end
Base.show(io::IO, r::Resource) = print(io, "$(r.id)")

"""
Compund resources that have a potential in addition to a flow rate,
these potential behave differently when summarized in a junction.
E.q. electric power which consist of voltage (potential) and power/current (flow rate),
    or gas which have both pressure (potential) and gas flow (flow rate).
"""
abstract type CompoundResource <: Resource end

"""
    ResourceEmit{T<:Real} <: Resource

Resources that can be emitted (*e.g.*, CO₂, CH₄, NOₓ).

These resources can be included as resources that are emitted, *e.g*, in the variable
[`emissions_strategic`](@ref man-opt_var-emissions).

# Fields
- **`id`** is the name/identifyer of the resource.
- **`co2_int::T`** is the CO₂ intensity, *e.g.*, t/MWh.
"""
struct ResourceEmit{T<:Real} <: Resource
    id::Any
    co2_int::T
end

"""
    ResourceCarrier{T<:Real} <: Resource

Resources that can be transported and converted.
These resources **cannot** be included as resources that are emitted, *e.g*, in the variable
[`emissions_strategic`](@ref man-opt_var-emissions).

# Fields
- **`id`** is the name/identifyer of the resource.
- **`co2_int::T`** is the CO₂ intensity, *e.g.*, t/MWh.
"""
struct ResourceCarrier{T<:Real} <: Resource
    id::Any
    co2_int::T
end

"""
    ResourcePotential{T<:Real} <: CompundResource

Resources that can be transported and converted, but also has a energy potential.

# Fields
- **`id`** is the name/identifyer of the resource.
- **`co2_int::T`** is the CO₂ intensity, *e.g.*, t/MWh.
"""
struct ResourcePotential{T<:Real} <: CompoundResource
    id::Any
    co2_int::T
    potential_id::Any
end

"""
    co2_int(p::Resource)

Returns the CO₂ intensity of resource `p`
"""
co2_int(p::Resource) = p.co2_int

"""
    is_resource_emit(p::Resource)

Checks whether the Resource `p` is of type `ResourceEmit`.
"""
is_resource_emit(p::Resource) = false
is_resource_emit(p::ResourceEmit) = true

"""
    res_sub(𝒫::Array{<:Resource}, sub = ResourceEmit)

Return resources that are of type `sub` for a given Array `::Array{Resource}`.
"""
res_sub(𝒫::Array{<:Resource}, sub = ResourceEmit) = filter(x -> isa(x, sub), 𝒫)

"""
    res_not(𝒩::Array{<:Resource}, res_inst)
    res_not(𝒫::Dict, res_inst::Resource)

Return all resources that are not `res_inst` for
- a given array `::Array{<:Resource}`.
  The output is in this case an `Array{<:Resource}`
- a given dictionary `::Dict`.
  The output is in this case a dictionary `Dict` with the correct fields
"""
res_not(𝒫::Array{<:Resource}, res_inst::Resource) = filter(x -> x != res_inst, 𝒫)
res_not(𝒫::Dict, res_inst::Resource) = Dict(k => v for (k, v) ∈ 𝒫 if k != res_inst)

"""
    res_em(𝒫::Array{<:Resource})
    res_em(𝒫::Dict)

Returns all emission resources for a
- a given array `::Array{<:Resource}`.
  The output is in this case an `Array{<:Resource}`
- a given dictionary `::Dict`.
  The output is in this case a dictionary `Dict` with the correct fields
"""
res_em(𝒫::Array{<:Resource}) = filter(is_resource_emit, 𝒫)
res_em(𝒫::Dict) = filter(p -> is_resource_emit(first(p)), 𝒫)

"""
    res_types(ℒ::Array{<:Link})

Return the unique resource types transported for a Array of resources `𝒫`.
"""
res_types(𝒫::Array{<:Resource}) = unique([typeof(p) for p in 𝒫])
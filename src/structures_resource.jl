"""
Resources that can be transported and converted.

# Fields
- **`id`** is the name/identifyer of the resource.\n
- **`co2_int::T`** is the the CO2 intensity.\n

"""
abstract type Resource end
Base.show(io::IO, r::Resource) = print(io, "$(r.id)")

"""
Resources that can can be emitted (e.g., CO2, CH4, NOx).

# Fields
- **`id`** is the name/identifyer of the resource.\n
- **`co2_int::T`** is the the CO2 intensity.\n

"""
struct ResourceEmit{T<:Real} <: Resource
    id
    co2_int::T
end

"""
General resources.
"""
struct ResourceCarrier{T<:Real} <: Resource
    id
    co2_int::T
end

"""
    co2_int(p::Resource)

Returns the CO2 intensity of resource `p`
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

Return all resources that are not `res_inst` for
 - a given array `::Array{<:Resource}`.\
 The output is in this case an `Array{<:Resource}`
 - a given dictionary `::Dict`.\
The output is in this case a dictionary `Dict` with the correct fields
"""
res_not(𝒫::Array{<:Resource}, res_inst::Resource) = filter(x -> x!=res_inst, 𝒫)
res_not(𝒫::Dict, res_inst::Resource) =  Dict(k => v for (k,v) ∈ 𝒫 if k != res_inst)

"""
    res_em(𝒫::Array{<:Resource})

Returns all emission resources for a
- a given array `::Array{<:Resource}`.\
The output is in this case an `Array{<:Resource}`
- a given dictionary `::Dict`.\
The output is in this case a dictionary `Dict` with the correct fields
"""
res_em(𝒫::Array{<:Resource}) = filter(is_resource_emit, 𝒫)
res_em(𝒫::Dict) =  filter(p -> is_resource_emit(first(p)), 𝒫)

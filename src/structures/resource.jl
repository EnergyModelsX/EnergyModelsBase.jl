"""
    abstract type Resource

General resource supertype to be used for the declaration of subtypes.
"""
abstract type Resource end
Base.show(io::IO, r::Resource) = print(io, "$(r.id)")

"""
    struct ResourceEmit{T<:Real} <: Resource

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
    struct ResourceCarrier{T<:Real} <: Resource

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
    resource_family(p::Resource)

Returns the type under which the resource `p` is grouped when the resources of a case are
segmented for the resource-specific functions ([`variables_flow_resource`](@ref),
[`constraints_resource`](@ref), and [`constraints_couple_resource`](@ref)). The default is
the concrete type of `p`, so that each concrete resource type forms its own segment.

Extension packages can return a common supertype for a family of resource types, *e.g.*,
`resource_family(::AbstractMyResource) = AbstractMyResource`, so that all resources of the
family are handed to the resource-specific functions in a single call. This allows the
extension package to create its variables once for the whole family and to dispatch
internally on the concrete types.
"""
resource_family(p::Resource) = typeof(p)

"""
    res_types(𝒫::Vector{<:Resource})

Return the unique resource families ([`resource_family`](@ref)) in a Vector of resources
`𝒫`. By default, these are the concrete resource types.
"""
res_types(𝒫::Vector{<:Resource}) = unique(map(resource_family, 𝒫))

"""
    res_types_vec(𝒫::Vector{<:Resource})

Return a Vector-of-Vectors of resources segmented by their resource family
([`resource_family`](@ref)), if the input is empty it returns an empty Vector. By default,
the segments correspond to the concrete sub-types.
"""
res_types_vec(𝒫::Vector{<:Resource}) =
    [Vector{rt}(filter(x -> resource_family(x) == rt, 𝒫)) for rt ∈ res_types(𝒫)]
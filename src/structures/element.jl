"""
    abstract type AbstractElement

Abstract elements correspond to the core types of `EnergyModelsBase` that form components of
an energy system.

# Introduced elements
- **[`Node`](@ref)s** correspond to technologies that convert energy or mass as defined
  through the introduced [`Resource`](@ref)s.
- **[`Link`](@ref)s** transport the [`Resource`](@ref)s between different nodes.

!!! tip "Additional AbstractElement"
    It is possible to introduce new elements. These elements can introduce also new variables
    and constraints.
"""
abstract type AbstractElement end


"""
    element_data(x::AbstractElement)

Returns the [`Data`](@ref) array of [`AbstractElement`](@ref) `x`. The function requires the
specification of a new method for each `AbstractElement`.

It is implemented in `EnergyModelsBase` for
- [`Node`](@ref) calling the subfunction [`node_data`](@ref) and
- [`Link`](@ref) calling the subfunction [`link_data`](@ref).
"""
element_data(x::AbstractElement) = Data[]

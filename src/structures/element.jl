"""
    abstract type AbstractElement

Abstract elements correspond to the core types of `EnergyModelsBase` that form components of
an energy system.

# Introduced elements
- **[`Node`](@ref)s** correspond to technologies that convert energy or mass as defined
  through the introduced [`Resource`](@ref)s.
- **[`Links`](@ref)s** transport the [`Resource`](@ref)s between different nodes.

!!! tip "Additional AbstractElement"
    It is possible to introduce new elements. These elements can introduce also new variables
    and constraints.
"""
abstract type AbstractElement end

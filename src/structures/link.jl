"""
    abstract type Formulation

Declaration of the general type for formulation of [`Link`](@ref)s. Formulations can be
utilized to provide specific constraint functions for a [`Link`](@ref) while keeping other
constraints unchanged. These subfunctions can be then utlized for several types of `Link`.
"""
abstract type Formulation end

"""
    struct Linear <: Formulation

Linear `Formulation`, that is input equals output."""
struct Linear <: Formulation end

"""
    abstract type Link <: AbstractElement

General supertype for links connecting [`Node`](@ref)s.
"""
abstract type Link <: AbstractElement end
Base.show(io::IO, l::Link) = print(io, "l_$(l.from)-$(l.to)")

"""
    struct Direct <: Link

A direct link between two nodes.

# Fields
- **`id`** is the name/identifier of the link.
- **`from::Node`** is the node from which there is flow into the link.
- **`to::Node`** is the node to which there is flow out of the link.
- **`formulation::Formulation`** is the used formulation of links. If not specified, a
  `Linear` link is assumed.
"""
struct Direct <: Link
    id::Any
    from::Node
    to::Node
    formulation::Formulation
end
Direct(id, from::Node, to::Node) = Direct(id, from, to, Linear())

"""
    link_sub(ℒ::Vector{<:Link}, n::Node)

Return connected links from the vector `ℒ` for a given node `n` as array.
The first subarray corresponds to the `from` field, while the second to the `to` field.
"""
function link_sub(ℒ::Vector{<:Link}, n::Node)
    return [filter(x -> x.from == n, ℒ), filter(x -> x.to == n, ℒ)]
end

"""
    is_unidirectional(l::Link)

Returns logic whether the link `l` can be used bidirectional or only unidirectional.

!!! note "Bidirectional flow in links"
    In the current stage, `EnergyModelsBase` does not include any links which can be used
    bidirectional, that is with flow reversal.

    If you plan to use bidirectional flow, you have to declare your own nodes and links which
    support this. You can then dispatch on this function for the incorporation.
"""
is_unidirectional(l::Link) = true

"""
    has_emissions(l::Link)

Checks whether link `l` has emissions.

By default, links do not have emissions. You must dispatch on this function if you want to
introduce links with associated emissions, *e.g.*, through leakage.
"""
has_emissions(l::Link) = false

"""
    has_capacity(l::Link)

Checks whether link `l` has a capacity.

By default, links do not have a capacity. You must dispatch on this function if you want to
introduce links with capacities.
"""
has_capacity(l::Link) = false

"""
    has_opex(l::Link)

Checks whether link `l` has operational expenses.

By default, links do not have operational expenses. You must dispatch on this function if
you want to introduce links with operational expenses.
"""
has_opex(l::Link) = false

"""
    link_res(l::Link)

Return the resources transported for a given link `l`.

The default approach is to use the intersection of the inputs of the `to` node and the
outputs of the `from` node.
"""
link_res(l::Link) = intersect(inputs(l.to), outputs(l.from))

"""
    inputs(n::Link)

Returns the input resources of a link `l`.

The default approach is to use the function [`link_res(l::Link)`](@ref).
"""
inputs(l::Link) = link_res(l)

"""
    outputs(n::Link)

Returns the output resources of a link `l`.

The default approach is to use the function [`link_res(l::Link)`](@ref).
"""
outputs(l::Link) = link_res(l)

"""
    formulation(l::Link)

Return the formulation of a Link `l`.
"""
formulation(l::Link) = l.formulation

"""
    link_data(l::Link)

Returns the [`ExtensionData`](@ref) array of link `l`.

The default options returns an empty `ExtensionData` vector.
"""
link_data(l::Link) = ExtensionData[]
element_data(l::Link) = link_data(l)

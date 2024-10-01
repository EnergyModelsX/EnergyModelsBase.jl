""" Declaration of the general type for formulation of links."""
abstract type Formulation end

""" Linear `Formulation`, that is input equals output."""
struct Linear <: Formulation end

""" Declaration of the general type for links connecting nodes."""
abstract type Link end
Base.show(io::IO, l::Link) = print(io, "l_$(l.from)-$(l.to)")

""" `Direct <: Link`

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
    link_res(l::Link)

Return the resources transported for a given link `l`.
"""
link_res(l::Link) = intersect(inputs(l.to), outputs(l.from))

"""
    formulation(l::Link)

Return the formulation of a Link `l`.
"""
formulation(l::Link) = l.formulation

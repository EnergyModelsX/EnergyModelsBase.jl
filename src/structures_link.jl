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
- **`id`** is the name/identifier of the link.\n
- **`from::Node`** is node from which there is flow into the link.\n
- **`to::Node`** is node to which there is flow out of the link.\n
- **`formulation::Formulation`** is the used formulation of links. If not specified, \
a `Linear` link is assumed.\n

"""
struct Direct <: Link
    id
    from::Node
    to::Node
    formulation::Formulation
end
Direct(id, from::Node, to::Node) = Direct(id, from, to, Linear())


"""
    link_sub(ℒ::Vector{<:Link}, n::Node)

Return connected links for a given node `n`.
"""
function link_sub(ℒ::Vector{<:Link}, n::Node)
    return [ℒ[findall(x -> x.from == n, ℒ)],
            ℒ[findall(x -> x.to   == n, ℒ)]]
end

"""
    link_res(l::Link)

Return the resources transported for a given link `l`.
"""
link_res(l::Link) = intersect(inputs(l.to), outputs(l.from))

"""
    formulation(l::Link)

Return the formulation of a Link ´l´.
"""
formulation(l::Link) = l.formulation

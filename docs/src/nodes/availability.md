# [Availability node](@id nodes-availability)

[`Availability`](@ref) nodes are routing technologies.
The aim of incorporating this type of nodes is to reduce the required number of links if you have multiple conversion technologies for a single energy carrier.
Consider, *e.g.*, a system in which you have 10 electricity generation technologies having electricity as output.
This could be a combination of [`Source`](@ref) and [`NetworkNode`](@ref).
You have furthermore 10 technologies requiring electricity as input as combination of [`NetworkNode`](@ref) and [`Sink`](@ref).

If you plan to allow for electricity transfer from all gebeneration to demand nodes, you would require in total ``10 \times 10 = 100`` links.
If you use the [`Availability`](@ref) instead, this would reduce to ``10 + 10 = 20`` links. significantly reducing the pre-processing requirement.
In the latter case, all nodes are connected to the [`Availability`](@ref) node.

!!! tip "Usage of `Availability`"
    It is still possible to have direct connection between individual nodes for given resources.
    This allows, *e.g.*, to investigate the trade-off between off-grid and on-grid electrolysis.
    In this case, the electrolysis node should not have an input connection with the [`Availability`](@ref) node, but with the electricity source node.
    Similarly, the electricity source node should not be connection to the [`Availability`](@ref) node.

    The [`Link`](@ref)s are only transferring a [`Resource`](@ref) if it is specified as the output of the origin node and the input of the destination node.
    This implies you can even have multiple connections from a node and avoid transfer *via* the [`Availability`](@ref) node.
    This is especially relevant for retrofit CO₂ capture.

## [Introduced type and its fields](@id nodes-availability-fields)

The [`GenAvailability`](@ref) node is implemented as a reference node that can be used for a [`Availability`](@ref).
It includes basic functionalities common to most energy system optimization models.

The fields of a [`GenAvailability`](@ref) node are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
- **`input::Vector{<:Resource}`** and **`output::Vector{<:Resource}`**:\
  Both fields describe the `input` and `output` [`Resource`](@ref)s as vectors.
  This approach is different to all other nodes, but simplifies the overall design.
  It is necessary to specify the same [`Resource`](@ref)s to allow for capacity usage in connected nodes.

!!! tip "Constructor `GenAvailability`"
    We require at the time being the specification of the fields `input` and `output` due to the way we identify the required
    flow and link variables.
    In practice, both fields should include the same [`Resource`](@ref)s.
    To this end, we provide a simplified constructor in which you only have to specify one vector using the function

    ```julia
    GenAvailability(id, 𝒫::Vector{<:Resource})
    ```

## [Mathematical description](@id nodes-availability-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-availability-math-var)

The variables of [`Availability`](@ref) nodes include:

- [``\texttt{flow\_in}``](@ref man-opt_var-flow)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)

### [Constraints](@id nodes-availability-math-con)

Availability nodes do not add by default any constraints, except for the constraints introduced in the function `create_node`(@ref).
This constraint is given by:

```math
\texttt{flow\_out}[n, t, p] = \texttt{flow\_in}[n, t, p] \qquad \forall p \in inputs(n)
```

This implies that standard availability nodes serve only as energy balance nodes for all other nodes.

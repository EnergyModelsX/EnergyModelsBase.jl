# [Creating a new node](@id create_new_node)

!!! warning "Unfinished how-to"
    This page is not finished.


The energy system model is based on the [JuMP](https://jump.dev/JuMP.jl/stable/)
optimization framework, so some basic knowledge on this Julia package is needed
to implement a new technology node.

> **To create a new technology node named `NewTechNode`, we need to**
>  1. Implement a new `struct` (composite type), that is a subtypes of `Node`,
>     `Source`, `Sink`, etc. Here, a central choice is to decide on [*what abstract node type to subtye*](@ref howto_create_node_subtype).
>  2. Optional: implement the method
>     ```julia
>     variables_node(m, 𝒩ˢᵘᵇ::Vector{<:NewTechNode}, 𝒯, modeltype::EnergyModel)
>     ``` 
>     Implementi this method if you want to create additional optimization variables for the new node. *See  [how to create JuMP variables](https://jump.dev/JuMP.jl/stable/manual/variables/) in the JuMP documentation.*
>  3. Implement the method
>     ```julia
>     create_node(m, n::NewTechNode, 𝒯, 𝒫, modeltype::EnergyModel)
>     ``` 
>      In this method the constraints for the new node are created. *See [how to create JuMP constraints](https://jump.dev/JuMP.jl/stable/manual/constraints/)*. You can also use the *[availabe constraint functions](@ref constraint_functions)*
>

### [What abstract node type should you subtype?](@id howto_create_node_subtype)

The choice of node supertype depends on what optimization variables you need for the constraints describing the functionality of the new node.

A new node is defined as a composite type (`struct`) and subtype of one of the standard node types,

- [`Source`](@ref)
- [`Network`](@ref)
- [`Sink`](@ref)

Furthermore, we have the types

- [`Availability`](@ref) `<: Network`
- [`Storage`](@ref) `<: Network`

which correspond to a routing node (`Availability`) and a storage node (`Storage`).

The chosen parent `type` of the `NewNodeType` node decides what optimization variables are created for use by default. The main difference between the individual parent types is whether they have only an energy/mass output (`Source`), input and output (`Network`), or input (`Sink`).

You can find the created default optimization variables in [OptimizationVariables](@ref optimization_variables)*.

### Example

As an example, you can check out how *[Renewable Producers](https://gitlab.sintef.no/clean_export/energymodelsrenewableproducers.jl)* introduces two new technology types, a `Sink` and a `Storage`.

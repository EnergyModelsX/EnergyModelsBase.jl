# [Create a new element](@id how_to-create_element)

```@meta
CurrentModule = EMB
```

## [Idea behind elements](@id how_to-create_element-idea)

`EnergyModelsBase` allows incorporating new elements.
These elements can have distinctive variables and constraints that are not inherited from the [`Link`](@ref) or [`Node`](@ref) types.
It is generally preferred to instead create a new link or node (as outlined on *[how to create a new node](@ref how_to-create_node)*).

## [Requirements](@id how_to-create_element-requirements)

It is necessary to be aware of the following limitations when you create a new subtype for `AbstractElement`.

Consider the case of a new abstract type

```julia
abstract type NewElement <: AbstractElement
```

You have to be aware of the following requirements.

1. A vector of the new subtype must be added to the field **`elements`** in addition to `Node` and `Link` vector in order to include new variables and constraints in a case description.
2. A majority of the included functions return as default nothing, when you do not specify a methods for your new `Vector{<:NewElement}`.
   The different functions for variable creation are:

   - [`variables_capacity`](@ref) for providing variables for capacity utilization and installed capacity,
   - [`variables_flow`](@ref) for providing inflow and outflow variables,
   - [`variables_opex`](@ref) for providing operating expenses variables,
   - [`variables_capex`](@ref) for providing capital expenditure variables,
   - [`variables_emission`](@ref) for providing emission variables, and
   - [`variables_elements`](@ref) and for providing subtype specific variables.

   The different functions for constraint creation are:

   - [`constraints_elements`](@ref) for providing the constraints for `Vector{<:NewElement}`,
   - [`emissions_operational`](@ref) for providing the contribution to the emissions,
   - [`objective_operational`](@ref) for providing the contribution to the operational costs, and
   - [`objective_invest`](@ref) for providing the contribution to the cost function for investments.

   In addition, we provide a check function:

   - [`check_elements`](@ref) to iterate throught the `Vector{<:NewElement}`.

3. If you plan to introduce coupling constraints between the `NewElement` and other `AbstractElement`s, you must create a new method for [`constraints_couple`](@ref) and supply a function for extracting the element from the case instance.
   The latter can be inspired by [`f_nodes`](@ref) and [`f_links`](@ref).

   !!! danger "Couplings with existing elements"
       Coupling a new element with existing elements is highly dangereous.
       A major problem is that you can create additional constraints that result in the problem being unfeasible.

       As an example, consider the function `constraints_couple` for nodes and links.
       In this function, we incorporate the coupling between the different links and nodes.
       In practice, a link can only have a single input and output, while a node can be connected to an arbirtrary number of links.
       If you now want to include a new element coupled to a `Node` *via* the flow variables, it is necessary that you only allow these couplings with a novel introduced node, in which the internal energy balance is adjusted to account for the new coupling.

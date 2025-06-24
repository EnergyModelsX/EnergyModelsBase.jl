# [Philosophy](@id man-phil)

## [General design philosophy](@id man-phil-gen)

One key aim in the development of `EnergyModelsBase` was to create an energy system model that

1. offers maximum flexibility with respect to the description of technologies,
2. is simple to extend with additional features without requiring changes in the core structure, and
3. is designed in a way such that the thought process for understanding the model is straight forward.

Julia as a programming language offers the flexibility required in points 1 and 2 through the concept of multiple dispatch.
`EnergyModelsBase` hence focuses on only creating variables and constraints that are used, instead of creating all potential constraints and variables and constrain a large fraction of these variables to a value of 0.
In that respect, `EnergyModelsBase` moves away from a parameter driven flexibility to a type driven flexibility.
Point 3 is achieved through a one direction flow in function calls, that is that we limit the number of required files and function calls for the individual technology constraint creations, and meaningful names of the individual functions.

The general concept of the model in `EnergyModelsBase` is based on a graph structure.
The technologies within the modeled energy system are represented by `Node`s.
These `Node`s correspond to, *eg*, a hydropower plant, a gas turbine, or the Haber-Bosch process.
The individual nodes are then connected *via* `Link`s/edges representing the transport of mass or energy between the technologies.
`EnergyModelsBase` is represented using directed graphs, that is, flow is only possible in one direction through the links.
The included `Resource`s 𝒫 are user defined.
These resources have a unit associated with them, although this is not modelled explicitly in the current implementation.
These units define the units/values that have to be applied when converting resources.

`EnergyModelsBase` does not include all necessary constraints for individual technologies.
Instead, it is seen as a lightweight core structure that can be extended by the user through the development of specific `Node` functions.
Potential additional `Node`s can focus on, *e.g.*:

1. Piecewise linear efficiencies of technologies,
2. Inclusion of ramping constraints for technologies for which these are relevant,
3. Minimmum capacity usage based on disjunctions, or
4. Improved description of start-up and shut-down energy and time demands through disjunctions

to name some of potential new constraints.

## [Description of technologies](@id man-phil-nodes)

The package utilizes different `type`s that represent components in an energy system.
These types can be summarized as:

1. [`Source`](@ref) types have only an ouput to the system. Practical examples are solar PV, wind power, or available resources at a given price.
2. [`NetworkNode`](@ref) types have both an input and an ouput. Practical examples are next to all technologies in an energy system, like *e.g.*, a natural gas reforming plant with CCS (input: natural gas and electricity, output: hydrogen and CO₂) or an electrolyser (input: electricity, output: hydrogen).
3. [`Sink`](@ref) types have only an input from the system. They correspond in general to an energy/mass demand.

In addition, there are two `type`s that are subtypes of `NetworkNode`:

1. [`Availability`](@ref) types are routing types. They guarantee the energy/mass balance of all connected inputs/outputs.
2. [`Storage`](@ref) types are a special subtype as they include different variables.

These `type`s are connected using `link`s that transport the energy/mass.

New technologies can be introduced by defining a new composite type for the technology.
You can find a description on how you can create a new node on the page *[Creating a new node](@ref how_to-create_node)*.

## [Extensions to the model](@id man-phil-ext)

There are in general four ways to extend the model:

1. Introducing new technology descriptions as described in *[Creating a new node](@ref how_to-create_node)*,
2. Call of the `create_model` function with subsequent function calls for adding additional constraints,
3. Dispatching on the type `EnergyModel`, and
4. Use the field `data` in the individual composite types.

Introducing new technology descriptions is the basis for extending the model.
This approach allows for a different mathematical description compared to the included reference nodes.
As an example, it is possible to introduce a new demand node that provides a profit for satisfying a demand combined with having no penalty if the demand is not satisfied.

Calling `create_model` within a new function allows the introduction of entirely new functions.
This approach is chosen in [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/) although it still uses dispatch on individual technology nodes.

Dispatching on the type `EnergyModel` allows for adding methods to all functions that have `modeltype` included in the call.
This is done in the package [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) where investments are added to the model through introducting the `abstract type` `AbstractInvestmentModel`.
It can be problematic when one also wants to use investments.
In addition, care has to be taken with respect to method amibiguity when dispatching on the type `EnergyModel`.

The `Array{ExtensionData}` field provides us with flexibility with respect to providing additional data to the existing nodes.
It is implemented in `EnergyModelsBase` for including emissions (both process and energy usage related).
In that case, it allows for flexibility through either saying whether process (or energy related emissions) are present, or not.
In addition, it allows for capturing the CO₂ from either the individual CO₂ sources (process and energy usage related), alternatively from both sources, or not at all.
The individual data types are explained in the Section *[Additional data](@ref lib-pub-mod_data-data)* in the public library as well as on *[ExtensionData functions](@ref man-data_fun)*.
In addition, it is already used in the package [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) through the introduction of the `abstract type` `InvestmentData` as subtype of `ExtensionData`.
The introduction of `InvestmentData` allows providing additional parameters to individual technologies.
However, the implementation in `EnergyModelsInvestments` does not utilize the extension through the *[ExtensionData functions](@ref man-data_fun)*.
Instead, as outlined above, it dispatches on the type `EnergyModel`.

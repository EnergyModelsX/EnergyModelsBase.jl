# Philosophy

## General design philosophy

One key aim in the development of `EnergyModelsBase` was to create an energy system model that

1. offers maximum flexibility with respect to the description of technologies,
2. is simple to extend with additional features without requiring changes in the core structure, and
3. is built simple so that the thought process for understanding the model is straight forward.

Julia as a programming language offers the  flexibility required in points 1 and 2 through the concept of multiple dispatch.
Point 3 is achieved through a one direction flow in function calls, that is that we limit the number of required files and function calls for the individual technology constraint creations, and meaningfull names to the individual functions. 

## Description of technologies

The package utilizes different `type`s that represent components in an energy system.
These types can be summarized as:

1. [`Source`](@ref) types have only an ouput to the system. Practical examples are solar PV, wind power, or available resources.
2. [`Network`](@ref) types have both an input and an ouput. Practical examples are next to all technologies in an energy system, like *e.g.*, a natural gas reforming plant with CCS (input: natural gas and electricity, output: hydrogen and CO<sub>2</sub>) or an electrolyser (input: electricity, output: hydrogen).
3. [`Sink`](@ref) types have only an input from the system. They correspond in general to an energy/mass demand.

In addition, there are two `type`s that are subtypes of `Network`:

1. [`Availability`](@ref) types are routing types. They guarantee the energy/mass balance of all connected inputs/outputs.
2. [`Storage`](@ref) types are a special subtype as they include different variables.

These `type`s are connected using `link`s that transport the energy/mass.

New technologies can be introduced by defining a new composite type for the technology.
You can find a description on how you can create a new node on the page *[Creating a new node](@ref create_new_node)*.

## Extensions to the model

There are in general four ways to extend the model:

1. Introducing new technology descriptions as described in *[Creating a new node](@ref create_new_node)*,
2. Call of the `create_model` function with subsequent functionc alls,
3. Dispatching on the type `EnergyModel`, and
4. Use the field `Data` in the individual composite types.

Calling `create_model` within a new function allows the introduction of entirely new functions.
This approach is chosen in [`EnergyModelsGeography.jl`](https://clean_export.pages.sintef.no/energymodelsgeography.jl/) although it still uses dispatch on individual technology nodes.

Dispatching on the type `EnergyModel` allows for adding methods to all functions that have `modeltype` included in the call.
This is done in the package [`EnergyModelsInvestments.jl`](https://clean_export.pages.sintef.no/energymodelsinvestments.jl/) where investments are added to the model through introducting the `abstract type` `AbstractInvestmentModel`.
It can be problematic when one also wants to use investments.
In addition, care has to be taken with respect to method amibiguity when dispatching on the type `EnergyModel`.

The last approach is used already in the package [`EnergyModelsInvestments.jl`](https://clean_export.pages.sintef.no/energymodelsinvestments.jl/) through the introduction of the `abstract type` `InvestmentData`.
The `Array{Data}` field allows us flexibility with respect to providing additional data to the existing nodes.
It is planned to change the implementation so that it is even easier to utilize thhis approach for model extension.

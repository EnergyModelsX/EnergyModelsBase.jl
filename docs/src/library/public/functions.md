# [General functions of `EnergyModelsBase`](@id lib-pub-fun)

## Index

```@index
Pages = ["functions.md"]
```

## [Functions for running the model](@id lib-pub-fun-run)

The following functions are provided for both creating a model using `EnergyModelsBase` and solving said model.
Both functions have the input `case` and `model`.
`run_model` calls `create_model` in the function, hence, it is not necessary to call the function beforehand.

The `case` dictionary has to follow a certain outline.
In this case, it is simplest to look at the provided *[examples](https://github.com/EnergyModelsX/EnergyModelsBase.jl/tree/main/examples)*.

!!! note
    We are currently debating to replace the dictionary used for `case` as well with a composite type.
    This will lead to breacking changes, but should be simple to adjust for.

```@docs
create_model
run_model
```

## [Functions for extending the model](@id lib-pub-fun-ext)

The following functions are used for developing new nodes.
See the page *[Creating a new node](@ref how_to-create_node)* for a detailed explanation on how to create a new node.

```@docs
variables_node
create_node
```

## [Constraint functions](@id lib-pub-fun-con)

```@meta
CurrentModule = EMB
```

The following functions can be used in newly developed nodes to include constraints.
See the pages *[Constraint functions](@ref man-con)* and *[Data functions](@ref man-data_fun)* for a detailed explanation on their usage.

!!! warning
    The function `constraints_capacity_installed` should not be changed.
    It is used for the inclusion of investments through `EnergyModelsInvestments` in the extension.
    It also has to be called, if you create a new function `constraints_capacity`.

```@docs
constraints_flow_in
constraints_flow_out
constraints_capacity
constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
constraints_level
constraints_level_aux
constraints_opex_var
constraints_opex_fixed
constraints_data
```

In addition, auxiliary functions are introduced for the calculation of the previous level of storage nodes.
These auxiliary functions provide the user with simple approaches for calculating the level balances.

```@docs
previous_level
previous_level_sp
```

## [Utility functions](@id lib-pub-fun-util)

The following function can be used in newly developed nodes to scale from operational to strategic periods.
The function replaced the previously used function [`EMB.multiple`] which is still available with a deprecation warning.

```@docs
scale_op_sp
```

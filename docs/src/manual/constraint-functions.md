# [Constraint functions](@id constraint_functions)

The package provides standard constraint functions that can be used for new developed nodes.
These standard constraint functions are used exclusively in all `create_node(m, n, 𝒯, 𝒫, modeltype)` functions.
They allow for both removing repititions of code as well as dispatching only on certain aspects.
The majority of the constraint functions are created for the `abstract type` of the `Node` dispatching, that is, the supertypes described in *[Description of Technologies](@ref sec_des_nodes)*.
If a constraint function is not using the `abstract type` for dispatching, a warning is shown in this manual.

## Capacity constraints

Capacity constraints are constraints that limit both the capacity usage and installed capacity.
The core function is given by

```julia
constraints_capacity(m, n::Node, 𝒯::TimeStructure, modeltype)
```

correponding to the constraint on the usage of the capacity of a technology node ``n``.
It is implemented for `Node`, `Storage`, and `Sink` types.
The general implementation is limiting the capacity usage. That is, limiting the variable ``\texttt{cap\_use}[n, t]`` to the maximum installed capacity ``\texttt{cap\_inst}[n, t]`` (and correspondingly for both rate and level variables for storage).
`Sink` nodes behave differently as we allow for both surplus (``\texttt{sink\_surplus}[n, t]``) and deficits (``\texttt{sink\_deficit}[n, t]``), as explained in *[`Sink` variables](@ref var_sink)*.

Within this function, the function

```julia
constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype)
```

is called to limit the variable ``\texttt{cap\_inst}`` (or ``\texttt{stor\_charge_\_inst}``, ``\texttt{stor\_level\_inst}`` and ``\texttt{stor\_discharge_\_inst}`` for `Storage` nodes) of a technology node ``n``.
This functions is also used to subsequently dispatch on model type for the introduction of investments.

!!! warning
    As the function `constraints_capacity_installed` is used for including investments for nodes, it is important that it is also called when creating a new node.
    It is not possible to only add a function for
    ```julia
    constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype)
    ```
    without adding a function for
    ```julia
    constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::EMI.AbstractInvestmentModel)
    ```
    as this can lead to a method ambiguity error.

## Flow constraints

Flow constraints handle how the flow variables of a `Node` are connected to the internal variables.
In `EnergyModelsBase`, we only consider capacity variables as internal variables.
This can however be extended through the development of new `Node`s, if desired.

```julia
constraints_flow_in(m, n::Node, 𝒯::TimeStructure, modeltype)
```

corresponds to the constraints calculating the required inflow to a node ``n`` for a given capacity usage.
It is implemented for `Node` (using ``\texttt{cap\_use}[n, t]``) and `Storage` (using ``\texttt{stor\_rate\_use}[n, t]``) types.

```julia
constraints_flow_out(m, n::Node, 𝒯::TimeStructure, modeltype)
```

corresponds to the constraints calculating the outflow of a node ``n`` for a given capacity usage.
It is implemented for `Node` types using ``\texttt{cap\_use}[n, t]`` but not used for the `Storage` subtypes introduced in the model.
The outflow of a `Storage` node is instead specified through the storage level balance.

## Storage level constraints

Storage level constraints are required to provide flexibility on how the level of a `Storage` node should be calculated depending on the chosen [`StorageBehavior`](@ref sec_lib_public_storbehav).

```julia
constraints_level(m, n::Storage, 𝒯, 𝒫, modeltype)
```

corresponds to the main constraint for calculating the level balance of a `Storage` node.
Within this constraint, two different functions are called:

```julia
constraints_level_aux(m, n::Storage, 𝒯, 𝒫, modeltype)
```

and

```julia
constraints_level_iterate(m, n::Storage, prev_pers, cyclic_pers, t_inv, ts, modeltype)
```

The first function, `constraints_level_aux`, is used to calculate additional properties of a `Storage` node.
These properties are independent of the chosen `TimeStructure`, but dependent on the stored `Resource` type and the storage type.
General properties are the calculation of the change in storage level in an operational period, as described in *[Capacity variables](@ref var_cap)* as well as bounds on variables.
It is implemented for a generic `Storage` node as well for a `RefStorage{AccumulatingEmissions}` node.
Using the `AccumulatingEmissions` requires that the stored resource is a `ResourceEmit` and limits the variable ``\texttt{stor\_level\_}\Delta\texttt{\_op}[n, t, p] \geq 0`` as well as introduces emission variables.

The second function, `constraints_level_iterate`, iterates through the time structure and eventually declares the level balance of the `Storage` node within a strategic period.
It automatically deduces the type of the time structure, _i.e._, whether representative periods and/or operational scenarios are included, and subsequently calculates the corresponding previous period used in the level balance through calling the function [`previous_level`](@ref).

`RepresentativePeriods` are handled through scaling of the change in the level in a representative period.
This requires that the `RepresentativePeriods` are sequential.

The total function call structure is given by:

```
constraints_level(m, n::Storage, 𝒯, 𝒫, modeltype)
├─ constraints_level_aux(m, n, 𝒯, 𝒫, modeltype)
└─ constraints_level_iterate(m, n, prev_pers, cyclic_pers, t_inv, ts::RepresentativePeriods, modeltype)
   ├─ constraints_level_rp(m, n, per, modeltype)
   └─ constraints_level_iterate(m, n, prev_pers, cyclic_pers, t_inv, ts::OperationalScenarios, modeltype)
      ├─ constraints_level_scp(m, n, per, modeltype)
      └─ constraints_level_iterate(m, n, prev_pers, cyclic_pers, t_inv, ts::SimpleTimes, modeltype)
         ├─ constraints_level_bounds(m, n, t, cyclic_pers, modeltype)
         └─ previous_level(m, n, prev_pers, cyclic_pers, modeltype)
            └─ previous_level_sp(m, n, cyclic_pers, modeltype)
```

Not all functions are called, as the framework automatically deduces the chosen time structure.
Hence, if the time structure is given as `TwoLevel{SimpleTimes}`, all functions related to representative epriods and scenario periods are omitted.

!!! tip "Introducing new storage behaviours"
    If you want to introduce a new *[storage behaviour](@ref sec_lib_public_storbehav)*, it is best to dispatch on the following functions.
    It is not necessary to dispatch on all of the mentioned functions for all storage behaviours.

    1. `constraints_level_rp(m, n, per, modeltype)` for inclusion of constraints on the variable [``\texttt{stor\_level\_Δ\_rp}[n, t_{rp}]``](@ref var_cap),
    2. `constraints_level_scp(m, n, per, modeltype)` for inclusion of constraints related to operational scenarios,
    3. `previous_level(m, n, prev_pers, cyclic_pers, modeltype)` for changing the behaviour of how previous storage levels should be calculated, and
    4. `previous_level_sp(m, n, cyclic_pers, modeltype)` for changing the behaviour of the first operational period (in the first representative period) within a strategic period.

    The exact implementation is not straight forward and care has to be taken if you want to dispatch on these functions to avoid method ambiguities.
    We plan on extending on the documentation on how you can best introduce new *[storage behaviours](@ref sec_lib_public_storbehav)* in a latter stage with an example.

## Operational expenditure constraints

Operational expenditure (OPEX) constraints calculate the contribution of operating a technology.
The constraints are declared for both the fixed and variable OPEX.

```julia
constraints_opex_fixed(m, n::Node, 𝒯::TimeStructure, modeltype)
```

corresponds to the constraints calculating the fixed operational costs of a technology node ``n``.
It is implemented for `Node`, `Storage`, and `Sink` types.
The fixed OPEX is in general dependent on the installed capacity.

`EnergyModelsBase` provides a default approach for calculating the variable OPEX of `Storage` nodes to allow for variations in the individually chosen *[storage parameters](@ref sec_lib_public_storpar)*.
Depending on the chosen storage parameters, the fixed OPEX can include the capacities for the charge (through the variable [``\texttt{stor\_charge\_inst}[n, t]``](@ref var_cap)), storage level (through the variable [``\texttt{stor\_level\_inst}[n, t]``](@ref var_cap)), and discharge (through the variable [``\texttt{stor\_discharge\_inst}[n, t]``](@ref var_cap)) capacities.
Note that the fixed OPEX can only be included if a storage parameter including a capacity is chosen.

`Sink` nodes use the variable [``\texttt{cap\_inst}``](@ref var_cap) for providing a demand.
They do not have a capacity in their basic implementation.
Hence, no fixed OPEX is calculated.

```julia
constraints_opex_var(m, n::Node, 𝒯::TimeStructure, modeltype)
```

corresponds to the constraints calculating the variable operational costs of a technology node ``n``.
It is implemented for `Node`, `Storage`, `RefStorage{T<:ResourceEmit}`, and `Sink` types.
The variable OPEX is in general dependent on the capacity usage.

As it is the case for the constraints for the fixed OPEX,  `EnergyModelsBase` provides a default approach for calculating the variable OPEX of `Storage` nodes to allow for variations in the individually chosen *[storage parameters](@ref sec_lib_public_storpar)*.
Depending on the chosen storage parameters, the fixed OPEX can include values for charging (through the variable [``\texttt{stor\_charge\_use}[n, t]``](@ref var_cap)), the storage level (through the variable [``\texttt{stor\_level}[n, t]``](@ref var_cap)), and discharging (through the variable [``\texttt{stor\_discharge\_use}[n, t]``](@ref var_cap)).

The variable OPEX calculations of `Sink` nodes include both the potential of a penalty for the surplus and deficit as described in *[`Sink` variables](@ref var_sink)*.

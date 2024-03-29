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
constraints_capacity(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

correponding to the constraint on the usage of the capacity of a technology node ``n``.
It is implemented for `Node`, `Storage`, and `Sink` types.
The general implementation is limiting the capacity usage. That is, limiting the variable ``\texttt{cap\_use}[n, t]`` to the maximum installed capacity ``\texttt{cap\_inst}[n, t]`` (and correspondingly for both rate and level variables for storage).
`Sink` nodes behave differently as we allow for both surplus (``\texttt{sink\_surplus}[n, t]``) and deficits (``\texttt{sink\_deficit}[n, t]``), as explained in *[`Sink` variables](@ref var_sink)*.

Within this function, the function

```julia
constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

is called to limit the variable ``\texttt{cap\_inst}`` (or ``\texttt{stor\_cap\_inst}`` and ``\texttt{stor\_rate\_inst}`` for `Storage` nodes) of a technology node ``n``.
This functions is also used to subsequently dispatch on model type for the introduction of investments.

!!! warning
    As the function `constraints_capacity_installed` is used for including investments for nodes, it is important that it is also called when creating a new node.
    It is not possible to only add a function for
    ```julia
    constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
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
constraints_flow_in(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

corresponds to the constraints calculating the required inflow to a node ``n`` for a given capacity usage.
It is implemented for `Node` (using ``\texttt{cap\_use}[n, t]``) and `Storage` (using ``\texttt{stor\_rate\_use}[n, t]``) types.

```julia
constraints_flow_out(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

corresponds to the constraints calculating the outflow of a node ``n`` for a given capacity usage.
It is implemented for `Node` types using ``\texttt{cap\_use}[n, t]`` but not used for the `Storage` subtypes introduced in the model.
The outflow of a `Storage` node is instead specified through the storage level balance.

## Storage level constraints

Storage level constraints are required to provide flexibility on how the level of a `Storage` node has to be calculated.

```julia
constraints_level(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)
```

corresponds to the main constraint for calculating the level balance of a `Storage` node.
Within this constraint, two different functions are called:

```julia
constraints_level_aux(m, n, 𝒯, 𝒫, modeltype::EnergyModel)
```

and

```julia
constraints_level_sp(m, n, t_inv, 𝒫, modeltype::EnergyModel)
```

The first function, `constraints_level_aux`, is used to calculate additional properties of a `Storage` node.
These properties are independent of the chosen `TimeStructure`, but dependent on the stored `Resource` type.
General properties are the calculation of the change in storage level in an operational period, as described in *[Capacity variables](@ref var_cap)* as well as bounds on variables.
It is implemented for the cases when the stored resource is either a `ResourceEmit`  or a `ResourceCarrier`.
Storing a `ResourceEmit` in a `RefStorage` node limits the variable ``\texttt{stor\_level\_}\Delta\texttt{\_op}[n, t, p] \geq 0`` as well as introduces emission variables.

The second function, `constraints_level_sp`, declares the level balance of the `RefStorage` node within a strategic period.
The difference betwen storing a `ResourceCarrier` and a `ResourceEmit` is given by how the level at the first operational period in a strategic period is treated.
While a `ResourceCarrier` uses circular constraints, that is, the first operational period in a strategic period is dependent on the last operational period in a strategic period, storing a `ResourceEmit` uses a value of 0 for the first operational period of a strategic period.

In addition, `RepresentativePeriods` can be handled through scaling of the change in the level in a representative period.
This requires that the `RepresentativePeriods` are sequential.

!!! warning
    Both `constraints_level_aux` and `constraints_level_sp` dispatch on `RefStorage` as they behave differently when a `ResourceEmit` or `ResourceCarrier` is stored.
    This implies that developing a new `Storage` node requires creating a new level balance.

## Operational expenditure constraints

Operational expenditure (OPEX) constraints calculate the contribution of operating a technology.
The constraints are declared for both the fixed and variable OPEX.

```julia
constraints_opex_fixed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

corresponds to the constraints calculating the fixed operational costs of a technology node ``n``.
It is implemented for `Node`, `Storage`, `RefStorage{T<:ResourceEmit}`, and `Sink` types.
The fixed OPEX is in general dependent on the installed capacity.

`Storage` nodes use a different variable for describing the installed capacity.
Hence, the fixed OPEX calculations differs.
The fixed OPEX of a `RefStorage` node is calculated using the installed capacity ([``\texttt{stor\_cap\_inst}``](@ref var_cap)) when the stored resource is a `ResourceCarrier` and using the installed rate ([``\texttt{stor\_rate\_inst}``](@ref var_cap)) when the stored resource is a `ResourceEmit`.

`Sink` nodes use the variable [``\texttt{cap\_inst}``](@ref var_cap) for providing a demand.
They do not have a capacity in their basic implementation.
Hence, no fixed OPEX is calculated.

```julia
constraints_opex_var(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

corresponds to the constraints calculating the variable operational costs of a technology node ``n``.
It is implemented for `Node`, `Storage`, `RefStorage{T<:ResourceEmit}`, and `Sink` types.
The variable OPEX is in general dependent on the capacity usage.

`Storage` nodes use a different variable for describing the capacity usage.
The variable OPEX of a `RefStorage` node is calculated using the inlet flow of the stored resource ([``\texttt{flow\_in}[n, t , p_\texttt{stor}]``](@ref var_flow)).
Storing a `ResourceEmit` allows also for emissions of the stored resource.
In this case, the emissions are not included in the variable OEPX calculations

The variable OPEX calculations of `Sink` nodes include both the potential of a penalty for the surplus and deficit as described in *[`Sink` variables](@ref var_sink)*.

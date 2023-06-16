# [Constraint functions](@id constraint_functions)

The package provides standard constraint functions that can be use for new developed nodes.

## Capacity constraints

```julia
constraints_capacity(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

correponds to the constraint on the usage of the capacity of a technology node ``n``.
It is implemented for `Node`, `Storage`, and `Sink` types.
Within this function, the function

```julia
constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

is called to limit the variable ``\texttt{:cap\_inst}`` (or ``\texttt{:stor\_cap\_inst}`` and ``\texttt{:stor\_rate\_inst}`` respectively for `Storage` nodes) of a technology node ``n``.
This functions is also used to subsequently dispatch on model type for the introduction of investments.

## Flow constraints

```julia
constraints_flow_in(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

corresponds to the constraints calculating the required inflow to a node ``n`` for a given capacity usage.
It is implemented for `Node` (using ``\texttt{:cap\_use}[n, t]``) and `Storage` (using ``\texttt{:stor\_cap\_use}[n, t]`` and ``\texttt{:stor\_rate\_use}[n, t]``) types.

```julia
constraints_flow_out(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

corresponds to the constraints calculating the required inflow to a node ``n`` for a given capacity usage.
It is implemented for `Node` types using ``\texttt{:cap\_use}[n, t]`` but not used for the `Storage` subtypes introduced in the model.
These constraints are directly specified within the respective `create_node` function.

## Operational cost constraints

```julia
constraints_opex_fixed(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

corresponds to the constraints calculating the fixed operational costs of a technology node ``n``.
It is implemented for `Node`, `Storage`, and `Sink` types.

```julia
constraints_opex_var(m, n::Node, 𝒯::TimeStructure, modeltype::EnergyModel)
```

corresponds to the constraints calculating the variable operational costs of a technology node ``n``.
It is implemented for `Node`, `Storage`, `RefStorageEmissions`, and `Sink` types.

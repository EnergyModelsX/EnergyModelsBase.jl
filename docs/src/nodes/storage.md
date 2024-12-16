# [Storage](@id nodes-storage)

[`Storage`](@ref) nodes are subtypes of [`Storage`](@ref) as they have in general an input and output (except for permanent CO₂ storage).
Storages require additional variables and parameters.
As a consequence, a new abstract type is specified.

## [Philosophy of Storage nodes](@id nodes-storage-phil)

[`Storage`](@ref) nodes differ from the other nodes as they are designed per default as *[parametric types](https://docs.julialang.org/en/v1/manual/types/#man-parametric-composite-types)* using the concept of [`EnergyModelsBase.StorageBehavior`](@ref).
In addition, capacities and operational expenses are not included at the first level of the composite type, but instead on a lower level.

### [Parametric implementation](@id nodes-storage-phil-parametric)

The parametric input is not applied for any field, but instead for allowing simplified dispatch on the individual storage behavior of a [`Storage`](@ref) node.
As `TimeStruct`, and hence, `EnergyModelsBase` supports the inclusion of both representative periods and operational scenarios, it was the aim in the design to provide a reusable approach for calculating the level balances.
The structure of the level balance calculation is explained on *[Storage level constraints](@ref man-con-stor_level)* while you can find the mathematical description in the Section *[Level constraints](@ref nodes-storage-math-con-level)*.

We differentiate between [`Accumulating`](@ref) and [`Cyclic`](@ref) storage behaviors.
The former allows for a net change of the storage level within an investment period, while the latter requires a cyclic behavior for the level balance.

A single concrete type is included for `Accumulating` using [`AccumulatingEmissions`](@ref). This type was introduced for [`ResourceEmit`](@ref) resources to represent a permanent storage node.
It was initially utilized for CO₂ storage.

Two concrete types are included for [`Cyclic`](@ref), [`CyclicRepresentative`](@ref) and [`CyclicStrategic`](@ref).
These two types differ only if the time structure includes representative periods.
If not, they are equivalent.
In the case of inclusion of representative periods, [`CyclicRepresentative`](@ref) enforces the cyclic constraint within a representative period while [`CyclicStrategic`](@ref) enforces the cyclic constraint within the investment period.
In the case of [`CyclicStrategic`](@ref), we hence allow for a net change in the storage level within a representative period.
This net change is then used for the scaling.

### [Capacities](@id nodes-storage-phil-capacities)

Storage nodes can have up to three capacities, `charge`, storage `level`, and `discharge`.
In practice, a storage allways requires a level capacity corresponding to the maximum amount of stored energy.
However, it is not necessary to include `charge` and `discharge` capacities if they are

1. not representing an additional cost and
2. it is possible to charge/discharge the storage within a single operational period.

In this case, the `Storage` implementation allows the user to specify [`EnergyModelsBase.AbstractStorageParameters`](@ref) reflecting the required input.
We allow for multiple combinations within [`EnergyModelsBase.AbstractStorageParameters`](@ref) containing a capacity, a variable OPEX, and/or a fixed OPEX.
This is beneficial for ,*e.g.*, compressed hydrogen storage in which the charge capacity requires investments in compressors, while the discharge capacity is purely limited by the structural limits.

The individual types are

- [`StorCapOpex`](@ref) - the capacity includes a **capacity** as well as a **fixed** and **variable** OPEX,
- [`StorCap`](@ref) - the capacity only includes a **capacity**,
- [`StorCapOpexVar`](@ref) - the capacity includes a **capacity** as well as a **variable** OPEX,
- [`StorCapOpexFixed`](@ref) - the capacity includes a **capacity** as well as a **fixed** variable OPEX, and
- [`StorOpexVar`](@ref) - the capacity includes only a **variable** OPEX.

`EnergyModelsBase` provides although union types for simplifying providing new dispatch.
These are [`EnergyModelsBase.UnionOpexFixed`](@ref), [`EnergyModelsBase.UnionOpexVar`](@ref), and [`EnergyModelsBase.UnionCapacity`](@ref).

## [Introduced type and its fields](@id nodes-storage-fields)

The [`RefStorage`](@ref) node is implemented as a reference node that can be used for a [`Storage`](@ref).
It includes basic functionalities common to most energy system optimization models.

The fields of a [`RefStorage`](@ref) are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
- **`charge::AbstractStorageParameters`**:\
    More information can be found on *[storage parameters](@ref lib-pub-nodes-stor_par)*.
- **`level::UnionCapacity`**:\
  The level storage parameters must include a capacity.
  More information can be found on *[storage parameters](@ref lib-pub-nodes-stor_par)*.
  !!! note "Permitted values for storage parameters in `charge` and `level`"
      If the node should contain investments through the application of [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
      Similarly, you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
      The variable operating expenses can be provided as `OperationalProfile` as well.
      In addition, all capacity and fixed OPEX values have to be non-negative.
- **`stor_res::ResourceEmit`**:\
  The `stor_res` is the stored [`Resource`](@ref Resource).
- **`input::Dict{<:Resource,<:Real}`** and **`output::Dict{<:Resource,<:Real}`**:\
  Both fields describe the `input` and `output` [`Resource`](@ref Resource)s with their corresponding conversion factors as dictionaries.
  It is not necessary to specify the stored [`Resource`](@ref Resource) (outlined above), but it is in general advisable.\
  All values have to be non-negative.
  !!! warning "Ratios for Storage"
      In the current implementation, we do not consider `output` conversion factors for the outflow from the [`RefStorage`](@ref) node.
      Similarly, we do not consider the `input` conversion factor of the stored resource.
      Instead, it is assumed that there is no loss of the stored resource in the storage.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current version, it is used for both providing `EmissionsData` and additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) is used.
  !!! note
      The field `data` is not required as we include a constructor when the value is excluded.

!!! danger "Discharge values for `RefStorage`"
    [`RefStorage`](@ref) nodes do **not** include a discharge capacity or corresponding operating expenses.
    Instead, it is possible to empty the storage within a single operational period.
    If you need to specify a discharge capacity (or want to implement it as a ratio to the charge capacity), you have to create a new [`Storage`](@ref) type.
    This is explain on *[Advanced creation of new nodes](@ref how_to-create_node-adv)*.

    In practice, the key change would be to provide an additional field called `discharge` to the new `Storage` type.

## [Mathematical description](@id nodes-storage-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-storage-math-var)

The variables of [`Storage`](@ref)s include:

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{stor\_level\_inst}``](@ref man-opt_var-cap)
- [``\texttt{stor\_level}``](@ref man-opt_var-cap)
- [``\texttt{stor\_charge\_inst}``](@ref man-opt_var-cap) if the `Storage` has the field `charge` with a capacity
- [``\texttt{stor\_charge\_use}``](@ref man-opt_var-cap)
- [``\texttt{stor\_discharge\_inst}``](@ref man-opt_var-cap) if the `Storage` has the field `discharge` with a capacity
- [``\texttt{stor\_discharge\_use}``](@ref man-opt_var-cap)
- [``\texttt{flow\_in}``](@ref man-opt_var-flow)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{stor\_level\_Δ\_op}``](@ref man-opt_var-cap)
- [``\texttt{stor\_level\_Δ\_rp}``](@ref man-opt_var-cap) if the `TimeStruct` includes `RepresentativePeriods`
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if specified through the function [`has_emissions`](@ref) or if you use a `RefStorage{AccumulatingEmissions}`.

### [Constraints](@id nodes-storage-math-con)

A qualitative overview of the individual constraints can be found on *[Constraint functions](@ref man-con)*.
This section focuses instead on the mathematical description of the individual constraints.
It omits the direction inclusion of the vector of network nodes (or all nodes, if nothing specific is implemented).
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N^{\text{Storage}}`` for all [`Storage`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all investment periods).

The following standard constraints are implemented for a [`Storage`](@ref) node.
[`Storage`](@ref) nodes utilize the declared method for all nodes 𝒩.
The constraint functions are called within the function [`create_node`](@ref).
Hence, if you do not have to call additional functions, but only plan to include a method for one of the existing functions, you do not have to specify a new [`create_node`](@ref) method.

- `constraints_capacity`:

  ```math
  \begin{aligned}
  \texttt{stor\_level\_use}[n, t] & \leq \texttt{stor\_level\_inst}[n, t] \\
  \texttt{stor\_charge\_use}[n, t] & \leq \texttt{stor\_charge\_inst}[n, t] \\
  \texttt{stor\_discharge\_use}[n, t] & \leq \texttt{stor\_discharge\_inst}[n, t]
  \end{aligned}
  ```

- `constraints_capacity_installed`:

  ```math
  \begin{aligned}
  \texttt{stor\_level\_inst}[n, t] & = capacity(level(n), t) \\
  \texttt{stor\_charge\_inst}[n, t] & = capacity(charge(n), t) \\
  \texttt{stor\_discharge\_inst}[n, t] & = capacity(discharge(n), t)
  \end{aligned}
  ```

  !!! tip "Using investments"
      The function `constraints_capacity_installed` is also used in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) to incorporate the potential for investment.
      Nodes with investments are then no longer constrained by the parameter capacity.

- `constraints_flow_in`:\
  The auxiliary resource constraints are independent of the chosen storage behavior:

  ```math
  \texttt{flow\_in}[n, t, p] = inputs(n, p) \times \texttt{flow\_in}[n, stor\_res(n)]
  \qquad \forall p \in inputs(n) \setminus \{stor\_res(n)\}
  ```

  The stored resource constraints are depending on the chosen storage behavior.
  If no behavior is specified, it is given by

  ```math
  \texttt{flow\_in}[n, t, stor\_res(n)] = \texttt{stor\_charge\_use}[n, t]
  ```

  If the storage behavior is [`AccumulatingEmissions`](@ref), it is given by

  ```math
  \texttt{flow\_in}[n, t, stor\_res(n)] = \texttt{stor\_charge\_use}[n, t] - \texttt{emissions\_node}[n, t, stor\_res(n)]
  ```

  This allows the storage node to provide a soft constraint for emissions.

- `constraints_flow_out`:

  ```math
  \texttt{flow\_out}[n, t, stor\_res(n)] = \texttt{stor\_discharge\_use}[n, t]
  ```

  !!! tip "Behavior in the case of `AccumulatingEmissions`"
      In this case, the constraints are still declared.
      The variables are however fixed to 0.
      Hence, it will have no impact.

- `constraints_level`:\
  The level constraints are more complex compared to the standard constraints.
  They are explained in detail below in *[Level constraints](@ref nodes-storage-math-con-level)*.

- `constraints_opex_fixed`:

  ```math
  \begin{aligned}
  \texttt{opex\_fixed}&[n, t_{inv}] = \\ &
    opex\_fixed(level(n), t_{inv}) \times \texttt{stor\_level\_inst}[n, first(t_{inv})] + \\ &
    opex\_fixed(charge(n), t_{inv}) \times \texttt{stor\_charge\_inst}[n, first(t_{inv})] + \\ &
    opex\_fixed(discharge(n), t_{inv}) \times \texttt{stor\_discharge\_inst}[n, first(t_{inv})]
  \end{aligned}
  ```

  !!! tip "Why do we use `first()`"
      The variables ``\texttt{stor\_level\_inst}`` are declared over all operational periods (see the section on *[Capacity variables](@ref man-opt_var-cap)* for further explanations).
      Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacities in the first operational period of a given investment period ``t_{inv}`` in the function `constraints_opex_fixed`.

- `constraints_opex_var`:

  ```math
  \begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\ \sum_{t \in t_{inv}}&
    opex\_var(level(n), t) \times \texttt{stor\_level}[n, t] \times scale\_op\_sp(t_{inv}, t) + \\ &
    opex\_var(charge(n), t) \times \texttt{stor\_charge\_use}[n, t] \times scale\_op\_sp(t_{inv}, t) + \\ &
    opex\_var(discharge(n), t) \times \texttt{stor\_discharge\_use}[n, t] \times scale\_op\_sp(t_{inv}, t)
  \end{aligned}
  ```

  !!! tip "The function `scale_op_sp`"
      The function [``scale\_op\_sp(t_{inv}, t)``](@ref scale_op_sp) calculates the scaling factor between operational and investment periods.
      It also takes into account potential operational scenarios and their probability as well as representative periods.

- `constraints_data`:\
  This function is only called for specified data of the storage node, see above.

!!! info "Implementation of capacity and OPEX"
    The capacity constraints, both `constraints_capacity` and `constraints_capacity_installed` are only set for capacities that are included through the corresponding field and if the corresponding *[storage parameters](@ref lib-pub-nodes-stor_par)* have a field `capacity`.
    Otherwise, they are omitted.
    The field `level` is required to have a storage parameter with capacity.

    Even if a `Storage` node includes the corresponding capacity field (*i.e.*, `charge`, `level`, and `discharge`), we only include the fixed and variable OPEX constribution for the different capacities if the corresponding *[storage parameters](@ref lib-pub-nodes-stor_par)* have a field `opex_fixed` and `opex_var`, respectively.
    Otherwise, they are omitted.

#### [Level constraints](@id nodes-storage-math-con-level)

The overall structure is outlined on *[Constraint functions](@ref man-con-stor_level)*.
The level constraints are called through the function `constraints_level` which then calls additional functions depending on the chosen time structure (whether it includes representative periods and/or operational scenarios) and the chosen *[storage behaviour](@ref lib-pub-nodes-stor_behav)*.

The constraints introduced in `constraints_level_aux` are given by

```math
\texttt{stor\_level\_Δ\_op}[n, t] = \texttt{stor\_charge\_use}[n, t] - \texttt{stor\_discharge\_use}[n, t]
```

corresponding to the change in the storage level in an operational period.
If the storage behavior is [`AccumulatingEmissions`](@ref), it is instead given by

```math
\texttt{stor\_level\_Δ\_op}[n, t] = \texttt{stor\_charge\_use}[n, t]
```

In this case, we also fix variables and provide lower bounds:

```math
\begin{aligned}
& \texttt{emissions\_node}[n, t, stor\_res(n)] \geq 0 \\
& \texttt{emissions\_node}[n, t, p_{em}] = 0 \qquad & \forall p_{em} \in P^{em} \setminus \{stor\_res(n)\} \\
& \texttt{stor\_level\_Δ\_op}[n, t] \geq 0 \\
& \texttt{stor\_discharge\_use}[n, t] = 0 \\
& \texttt{flow\_out}[n, t, p] = 0 \qquad & \forall p \in output(n)
\end{aligned}
```

If the time structure includes representative periods, we calculate the change of the storage level in each representative period within the function `constraints_level_iterate`:

```math
\texttt{stor\_level\_Δ\_rp}[n, t_{rp}] = \sum_{t \in t_{rp}}
\texttt{stor\_level\_Δ\_op}[n, t] \times scale\_op\_sp(t_{rp}, t)
```

In the case of [`CyclicStrategic`](@ref), we add an additional constraint to the change in the function `constraints_level_rp`:

```math
\sum_{t_{rp} \in T^{rp}} \texttt{stor\_level\_Δ\_rp}[n, t_{rp}] = 0
```

while we fix the value in the case of [`CyclicRepresentative`](@ref) to 0:

```math
\texttt{stor\_level\_Δ\_rp}[n, t_{rp}] = 0
```

`Accumulating` storage behaviors do not add any constraint for the variable ``\texttt{stor\_level\_Δ\_rp}``.

If the time structure includes operational scenarios using [`CyclicRepresentative`](@ref), we enforce that the last value in each operational scenario is the same within the function `constraints_level_scp`.

The general level constraint is eventually calculated in the function `constraints_level_iterate`:

```math
\texttt{stor\_level}[n, t] = prev\_level +
\texttt{stor\_level\_Δ\_op}[n, t] \times duration(t)
```

in which the value ``prev\_level`` is depending on the type of the previous operational (``t_{prev}``) and strategic level (``t_{inv,prev}``) (as well as the previous representative period (``t_{rp,prev}``)).
It is calculated through the function `previous_level`.

We can distinguish the following cases:

1. The first operational period (in the first representative period) in an investment period (given by ``typeof(t_{prev}) = typeof(t_{rp, prev}) = = nothing``).
   In this situation, the previous level is dependent on the chosen storage behavior.
   In the default case of a [`Cyclic`](@ref) behaviors, it is given by the last operational period of either the strategic or representative period:

   ```math
   \begin{aligned}
     prev\_level & = \texttt{stor\_level}[n, last(t_{sp})]
     prev\_level & = \texttt{stor\_level}[n, last(t_{rp})]
   \end{aligned}
   ```

   If the storage behavior is instead given by [`CyclicStrategic`](@ref) and the time structure includes representative periods, we calculate the previous level instead as:

   ```math
   \begin{aligned}
   t_{rp,last}  = & last(repr\_periods(t_{sp})) \\
   prev\_level = & \texttt{stor\_level}[n, first(t_{rp,last})] - \\ &
     \texttt{stor\_level\_Δ\_op}[n, first(t_{rp,last})] \times duration(first(t_{rp,last})) + \\ &
     \texttt{stor\_level\_Δ\_rp}[n, t_{rp,last}]
   \end{aligned}
   ```

   ``t_{rp,last}`` corresponds in this situation to the last representative period in the current investment period.

   If the storage behavior is instead given by [`Accumlating`](@ref), the previous level is set to 0:

   ```math
   prev\_level = 0
   ```

2. The first operational period in subsequent representative periods in any investment period (given by ``typeof(t_{prev}) = nothing``).
   The previous level is again dependent on the chosen storage behavior.
   The default approach calculates it as:

   ```math
   \begin{aligned}
    prev\_level = & \texttt{stor\_level}[n, first(t_{rp,prev})] - \\ &
      \texttt{stor\_level\_Δ\_op}[n, first(t_{rp,prev})] \times duration(first(t_{rp,prev})) + \\ &
      \texttt{stor\_level\_Δ\_rp}[n, t_{rp,prev}]
   \end{aligned}
   ```

   while a [`CyclicRepresentative`](@ref) storage behavior calculates it as:

   ```math
   prev\_level = \texttt{stor\_level}[n, last(t_{rp})]
   ```

   This situation only occurs in cases in which the time structure includes representative periods.

3. All other operational periods:\

   ```math
    prev\_level = \texttt{stor\_level}[n, t_{prev}]
   ```

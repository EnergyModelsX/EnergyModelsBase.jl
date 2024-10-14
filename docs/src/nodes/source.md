# [Source node](@id nodes-source)

[`Source`](@ref) nodes are technologies that only have an output connection.

## [Introduced type and its fields](@id nodes-source-fields)

The [`RefSource`](@ref) node is implemented as a reference node that can be used for a [`Source`](@ref).
It includes basic functionalities common to most energy system optimization models.

The fields of a [`RefSource`](@ref) node are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
- **`cap::TimeProfile`**:\
  The installed capacity corresponds to the nominal capacity of the node.\
  If the node should contain investments through the application of [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`opex_var::TimeProfile`**:\
  The variable operational expenses are based on the capacity utilization through the variable [`:cap_use`](@ref man-opt_var-cap).
  Hence, it is directly related to the specified `output` ratios.
  The variable operating expenses can be provided as `OperationalProfile` as well.
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@ref how_to-utilize_TS)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`output::Dict{<:Resource,<:Real}`**:\
  The field `output` includes [`Resource`](@ref Resource)s with their corresponding conversion factors as dictionaries.
  CO₂ cannot be directly specified, *i.e.*, you cannot specify a ratio.
  If you would like to use a `Source` node with CO₂ as output with a given ratio, it is necessary to utilize the package [`EnergyModelsCO2`](https://energymodelsx.github.io/EnergyModelsCO2.jl/).
  If you use [`CaptureData`](@ref), it is however necessary to specify CO₂ as output, although the ratio is not important.\
  All values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current version, it is used for both providing `EmissionsData` and additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) is used.
  When using `EmissionsData`, only process emissions can be considered, that is the types [`EmissionsProcess`](@ref) and that is the types [`EmissionsProcess`](@ref) and [`CaptureProcessEmissions`](@ref).
  Specifying energy related emissions will not have an impact as there is no energy conversion within a `Source` node.
  !!! note
      The field `data` is not required as we include a constructor when the value is excluded.

!!! warning "Using `CaptureData`"
    If you plan to use [`CaptureData`](@ref) for a [`RefSource`](@ref) node, it is crucial that you specify your CO₂ resource in the `output` dictionary.
    The chosen value is however **not** important as the CO₂ flow is automatically calculated based on the process utilization and the provided process emission value.
    The reason for this necessity is that flow variables are declared through the keys of the `output` dictionary.
    Hence, not specifying CO₂ as `output` resource results in not creating the corresponding flow variable and subsequent problems in the design.

    We plan to remove this necessity in the future.
    As it would most likely correspond to breaking changes, we have to be careful to avoid requiring major changes in other packages.

## [Mathematical description](@id nodes-source-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-source-math-var)

The variables of [`Source`](@ref) nodes include:

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{cap\_use}``](@ref man-opt_var-cap)
- [``\texttt{cap\_inst}``](@ref man-opt_var-cap)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if `EmissionsData` is added to the field `data`
  Note that [`Source`](@ref) nodes are not compatible with [`CaptureData`](@ref) except for [`CaptureProcessEmissions`](@ref).
  Hence, you can only provide [`EmissionsProcess`](@ref EmissionsProcess) to the node.

### [Constraints](@id nodes-source-math-con)

A qualitative overview of the individual constraints can be found on *[Constraint functions](@ref man-con)*.
This section focuses instead on the mathematical description of the individual constraints.
It omits the direction inclusion of the vector of source nodes (or all nodes, if nothing specific is implemented).
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N^{\text{Source}}`` for all [`Source`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

The following standard constraints are implemented for a [`Source`](@ref) node.
[`Source`](@ref) nodes utilize the declared method for all nodes 𝒩.
The constraint functions are called within the function [`create_node`](@ref).
Hence, if you do not have to call additional functions, but only plan to include a method for one of the existing functions, you do not have to specify a new [`create_node`](@ref) method.

- `constraints_capacity`:

  ```math
  \texttt{cap\_use}[n, t] \leq \texttt{cap\_inst}[n, t]
  ```

- `constraints_capacity_installed`:

  ```math
  \texttt{cap\_inst}[n, t] = capacity(n, t)
  ```

  !!! tip "Using investments"
      The function `constraints_capacity_installed` is also used in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) to incorporate the potential for investment.
      Nodes with investments are then no longer constrained by the parameter capacity.

- `constraints_flow_out`:

  ```math
  \texttt{flow\_out}[n, t, p] =
  outputs(n, p) \times \texttt{cap\_use}[n, t]
  \qquad \forall p \in outputs(n) \setminus \{\text{CO}_2\}
  ```

- `constraints_opex_fixed`:

  ```math
  \texttt{opex\_fixed}[n, t_{inv}] = opex\_fixed(n, t_{inv}) \times \texttt{cap\_inst}[n, first(t_{inv})]
  ```

  !!! tip "Why do we use `first()`"
      The variable ``\texttt{cap\_inst}`` is declared over all operational periods (see the section on *[Capacity variables](@ref man-opt_var-cap)* for further explanations).
      Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacity in the first operational period of a given strategic period ``t_{inv}`` in the function `constraints_opex_fixed`.

- `constraints_opex_var`:

  ```math
  \texttt{opex\_var}[n, t_{inv}] = \sum_{t \in t_{inv}} opex\_var(n, t) \times \texttt{cap\_use}[n, t] \times scale\_op\_sp(t_{inv}, t)
  ```

  !!! tip "The function `scale_op_sp`"
      The function [``scale\_op\_sp(t_{inv}, t)``](@ref scale_op_sp) calculates the scaling factor between operational and strategic periods.
      It also takes into account potential operational scenarios and their probability as well as representative periods.

- `constraints_data`:\
  This function is only called for specified additional data, see above.

# [Sink node](@id nodes-sink)

[`Sink`](@ref) nodes are technologies that only have an input connection.
In the context of `EnergyModelsBase`, they correspond to a demand.

## [Introduced type and its fields](@id nodes-sink-fields)

The [`RefSink`](@ref) node is implemented as a reference node that can be used for a [`Sink`](@ref).
It includes basic functionalities common to most energy system optimization models.

The fields of a [`RefSink`](@ref) node are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
- **`cap::TimeProfile`**:\
  The installed capacity corresponds to the nominal demand of the node.\
  If the node should contain investments through the application of [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`penalty::Dict{Symbol,<:TimeProfile}`**:\
  The penalty dictionary is used for providing penalties for soft constraints to allow for both over and under delivering the demand.\
  It must include the fields `:surplus` and `:deficit`.
  In addition, it is crucial that the sum of both values is larger than 0 to avoid an unconstrained model.
- **`input::Dict{<:Resource,<:Real}`**:\
  The field `input` includes [`Resource`](@ref Resource)s with their corresponding conversion factors as dictionaries.\
  All values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current version, it is used for both providing `EmissionsData` and additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) is used.
  !!! note
      The field `data` is not required as we include a constructor when the value is excluded.
  !!! danger "Using `CaptureData`"
      As a `Sink` node does not have any output, it is not possible to utilize `CaptureData`.
      If you still plan to specify it, you will receive an error in the model building.

## [Mathematical description](@id nodes-sink-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-sink-math-var)

The variables of [`Sink`](@ref) nodes include:

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{cap\_use}``](@ref man-opt_var-cap)
- [``\texttt{cap\_inst}``](@ref man-opt_var-cap)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{sink\_surplus}``](@ref man-opt_var-sink)
- [``\texttt{sink\_deficit}``](@ref man-opt_var-sink)
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if `EmissionsData` is added to the field `data`

### [Constraints](@id nodes-sink-math-con)

A qualitative overview of the individual constraints can be found on *[Constraint functions](@ref man-con)*.
This section focuses instead on the mathematical description of the individual constraints.
It omits the direction inclusion of the vector of sink nodes (or all nodes, if nothing specific is implemented).
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N^{\text{Sink}}`` for all [`Sink`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

The following standard constraints are implemented for a [`Sink`](@ref) node.
[`Sink`](@ref) nodes utilize the declared method for all nodes 𝒩.
The constraint functions are called within the function [`create_node`](@ref).
Hence, if you do not have to call additional functions, but only plan to include a method for one of the existing functions, you do not have to specify a new [`create_node`](@ref) method.

- `constraints_capacity`:

  ```math
  \texttt{cap\_use}[n, t] + \texttt{sink\_deficit}[n, t] = \texttt{cap\_inst}[n, t] + \texttt{sink\_surplus}[n, t]
  ```

- `constraints_capacity_installed`:

  ```math
  \texttt{cap\_inst}[n, t] = capacity(n, t)
  ```

  !!! tip "Using investments"
      The function `constraints_capacity_installed` is also used in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) to incorporate the potential for investment.
      Nodes with investments are then no longer constrained by the parameter capacity.

- `constraints_flow_in`:

  ```math
  \texttt{flow\_in}[n, t, p] =
  inputs(n, p) \times \texttt{cap\_use}[n, t]
  \qquad \forall p \in inputs(n)
  ```

  !!! tip "Multiple inputs"
      The constrained above allows for the utilization of multiple inputs with varying ratios.
      it is however necessary to deliver the fixed ratio of all inputs.

- `constraints_opex_fixed`:\
  The current implementation fixes the fixed operating expenses of a sink to 0.

  ```math
  \texttt{opex\_fixed}[n, t_{inv}] = 0
  ```

- `constraints_opex_var`:

  ```math
  \begin{aligned}
  \texttt{opex\_var}[n, t_{inv}] = & \\
    \sum_{t \in t_{inv}} & surplus\_penalty(n, t) \times \texttt{sink\_surplus}[n, t] + \\ &
    deficit\_penalty(n, t) \times \texttt{sink\_deficit}[n, t] \times \\ &
    EMB.multiple(t_{inv}, t)
  \end{aligned}
  ```

  !!! tip "The function `EMB.multiple`"
      The function [``EMB.multiple(t_{inv}, t)``](@ref EnergyModelsBase.multiple) calculates the scaling factor between operational and strategic periods.
      It also takes into account potential operational scenarios and their probability as well as representative periods.

- `constraints_data`:\
  This function is only called for specified additional data, see above.

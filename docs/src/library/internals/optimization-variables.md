# [Optimization variables](@id optimization_variables)

## General variables

All nodes ``n`` (except [`Availability`](@ref)-nodes) have the following the variables

- ``\texttt{:opex\_var}[n, t_\texttt{inv}]``: Variable operational costs,
- ``\texttt{:opex\_fixed}[n, t_\texttt{inv}]``: Fixed operational costs, and
- ``\texttt{:emissions\_node}[n, t, p_\texttt{em}]``:  Emissions of the node

created at at strategic period ``t_\texttt{inv}`` or operational period ``t``.
``p_\texttt{em}`` defines the different `ResourceEmit` resources that are introduced in the `case` structure.

## Flow variables

Flow variables correspond to the input and output to the technology node. The following flow variables are defined for the nodes:

- ``\texttt{:flow\_in}[n, t, p]`` measures the flow rate of resource ``p`` into node ``n`` at operational period ``t``. It is created for subtypes of the types `Network` and `Sink` based on the field `Input` in the `struct`.
- ``\texttt{:flow\_out}[n, t, p]`` measures the flow rate of resource ``p`` out of node ``n`` at operational period ``t``. It is created for created for subtypes of the types `Source` and `Network` based on the field `Output` in the `struct`.

The flow is always given for a single hour.
This means that the total quantity that flows into a node ``n`` during the operational period ``t`` is found by 

```julia
m[:flow_in][n, t, p] * t.duration
```

The multiplication then leads to an energy/mass quantity in stead of an energy/mass flow.

## Capacity variables

The capacity variables are also created for all nodes except for ([`Availability`](@ref) nodes).
They differentiate between `Storage` nodes and other node types.

The following capacity variables are created for node types different than `Storage`:

- ``\texttt{:cap\_use}[n, t]``: Capacity usage of node ``n`` at operational period ``t``. This value is in absolute terms and not relative.
- ``\texttt{:cap\_inst}[n, t]``: Installed capacity of node ``n`` at operational period ``t``.

The capacity variables for `Storage` nodes differentiate between storage capacity (stored energy in the `Storage` node) or rate of storage (storage rate of a `Storage` node).
This leads then to the following variables:

- ``\texttt{:stor\_level}[n, t]``: Absolute level of energy/mass stored in a `Storage` node ``n`` at operational period ``t``,
- ``\texttt{:stor\_cap\_inst}[n, t]``: Installed storage capacity in a `Storage` node ``n`` at operational period ``t``,
- ``\texttt{:stor\_rate\_use}[n, t]``: Usage of the rate of a `Storage` node ``n`` at operational period ``t``, and
- ``\texttt{:stor\_rate\_inst}[n, t]``: Maximum available rate of a `Storage` node ``n`` at operational period ``t``.

## `Sink` variables

`Sink` nodes are somehow different to the other nodes as they have additional variables associated with them.
A key point here is to keep the overall mass balance intact.
These variables are:

- ``\texttt{:sink\_surplus}[n, t]``: Surplus of energy/mass to `Sink` ``n`` at operational period ``t``, and
- ``\texttt{:sink\_deficit}[n, t]``: deficit of energy/mass to `Sink` ``n`` at operational period ``t``.

## Other variables

The following variables are not associated with any nodes:

- ``\texttt{:emissions\_total}[t, p_\texttt{em}]``: Total emissions of `ResourceEmit` ``p_\texttt{em}`` in operational period ``t``, and
- ``\texttt{:emissions\_strategic}[t_\texttt{inv}, p_\texttt{em}]``: Total emissions of `ResourceEmit` ``p_\texttt{em}`` in strategic period ``t_\texttt{inv}``.

 These variables are introduced to calculate the total emissions both within an operational and a strategic period.
 
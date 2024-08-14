# [Optimization variables](@id man-opt_var)

`EnergyModelsBase` creates a variety of default variables for the individual nodes and edges.
These default variables are in general also created when new `Node`s or `Link`s are developed.
It is not necessary to utilize all of the default variables in the individual nodes.
It is however recommended to include in this situation constraints or fixes using either the `@constraint` macro or alternatively the `JuMP` function `fix(x, value)`.
The latter is the recommended approach.

!!! note
    The majority of the variables in `EnergyModelsBase` are rate variables.
    This imples that they are calculated for either an operational period duration of 1, when indexed over operational period ``t`` or a strategic period duration of 1, when indexed over strategic period ``t_\texttt{inv}``.
    Typical units for rates are MW for energy streams, tonne/hour for mass streams, tonne/year for strategic emissions, and €/year for operational expenditures.
    In this example, the duration of an operational period of 1 corresponds to an hour, while the duration of a strategic period of 1 corresponds to a year.

    Variables that are energy/mass based have that property highlighted in the documentation below.
    In the standard implementation of `EnergyModelsBase`, this is only the case for the level of a `Storage` node, the change of level of the node, and its installed capacity.

Rate variables can as well be translated to mass/energy variables.
As an example, the total quantity that flows into a node ``n`` during the operational period ``t`` can found by

```julia
m[:flow_in][n, t, p] * duration(t)
```

The multiplication then leads to an energy/mass quantity in stead of an energy/mass flow.

The coupling of strategic and operational periods can be achieved through the function `EMB.multiple(t, t_inv)`.
This functions allows for considering the scaling of the operational periods within a strategic period.

## [Operational cost variables](@id man-opt_var-opex)

Operational cost variables are included to account for operational expenditures (OPEX) of the model.
These costs are pure dependent on either the use or the installed capacity of a node ``n``.
All nodes ``n`` (except [`Availability`](@ref)-nodes) have the following variables representing the operational costs of the nodes:

- ``\texttt{opex\_var}[n, t_\texttt{inv}]``: Variable OPEX of node ``n`` in strategic period ``t_\texttt{inv}``.
- ``\texttt{opex\_fixed}[n, t_\texttt{inv}]``: Fixed OPEX of node ``n`` in strategic period ``t_\texttt{inv}``.

The variable OPEX is a cost that derives from using a technology.
It is calculated using the function [`constraints_opex_var`](@ref).
In general, it represents unmodelled feed to a process and the associated costs.
Examples are catalyst replacement, cooling water or process water.
The variable OPEX can also be utilized to provide values for a profit through using a technology.

The fixed OPEX is a cost that is independent of the usage of a technology.
Instead, it is only dependent on the installed capacity.
It is calculated using the function [`constraints_opex_fixed`](@ref).
It represents fixed costs like labour cost, maintenance, as well as insurances and taxes.

## [Capacity variables](@id man-opt_var-cap)

Capacity variables focus on both the capacity usage and installed capacity.
The capacity variables are also created for all nodes except for [`Availability`](@ref) nodes.
Capacity variables are differentiated between `Storage` nodes and all other `Node`s.
The implementation of the capacity variables allows for a time-varying capacity during an operational period for inclusion of variations in the demand in `Sink` nodes.
It is however not possible to invest into a time-varying capacity.

The following capacity variables are created for node types other than `Storage`:

- ``\texttt{cap\_use}[n, t]``: Absolute capacity usage of node ``n`` at operational period ``t``, and
- ``\texttt{cap\_inst}[n, t]``: Installed capacity of node ``n`` at operational period ``t``.

The capacity usage ``\texttt{cap\_use}`` is the utilization of the installed capacity.
It is declared in absolute values to avoid bilinearities when investing in capacities.
It is normally constrained by the variable ``\texttt{cap\_inst}`` of the individual nodes, except for `Sink` nodes.

The capacity variables for `Storage` nodes differentiate between storage capacity (stored energy in the `Storage` node) and rate of storage (storage rate of a `Storage` node).
The latter is furthermore differentiated between charging and discharging a `Storage` node.
A key reasoning for this approach is that it is in general possible to invest both in the storage rate (_e.g._, the AC-DC transformer required in battery storage) as well as the storage capacity (_e.g._ the number of cells in battery storage).
The same holds as well for pumped hydro storage and storage of gases where there is a further differentiation between the maximum charging and discharging rates.
The differentiation leads to the following variables for `Storage` nodes:

- ``\texttt{stor\_level}[n, t]``: Absolute level of energy/mass stored in a `Storage` node ``n`` at operational period ``t`` with a typical unit of GWh or t,
- ``\texttt{stor\_level\_inst}[n, t]``: Installed storage capacity in a `Storage` node ``n`` at operational period ``t`` , that is the upper bound for the variable ``\texttt{stor\_level}[n, t]``, with a typical unit of GWh or t,
- ``\texttt{stor\_charge\_use}[n, t]``: Usage of the charging rate of a `Storage` node ``n`` at operational period ``t`` with a typical unit of GW or t/h,
- ``\texttt{stor\_charge\_inst}[n, t]``: Maximum available charging rate of a `Storage` node ``n`` at operational period ``t``, that is the upper bound for the variable ``\texttt{stor\_charge\_use}[n, t]``, with a typical unit of GW or t/h.
- ``\texttt{stor\_discharge\_use}[n, t]``: Usage of the discharging rate of a `Storage` node ``n`` at operational period ``t`` with a typical unit of GW or t/h, and
- ``\texttt{stor\_discharge\_inst}[n, t]``: Maximum available discharging rate of a `Storage` node ``n`` at operational period ``t``, that is the upper bound for the variable ``\texttt{stor\_discharge\_use}[n, t]``, with a typical unit of GW or t/h.

!!! note
    It is not necessary that a `Storage` node has a charge and discharge capacity.
    It is possible to not specify a capacity for charge and discharge.
    In this instance, the variables for the intalled capacities are omitted and the charge and discharge usage is unlimited.

The storage level is always defined for the end of the operational period it is indexed over.
There are in addition two variables for the storage level that behave slightly different:

- ``\texttt{stor\_level\_Δ\_op}[n, t]``: Change of the absolute level of energy/mass stored in a `Storage` node ``n`` in operational period ``t`` with a typical unit of GWh or t, and
- ``\texttt{stor\_level\_Δ\_rp}[n, t_{rp}]``: Change of the absolute level of energy/mass stored in a `Storage` node ``n`` in representative period ``t_{rp}`` with a typical unit of GWh or t.

These two variables are introduced to track the change in the storage level in a operational period and a representative period, respectively.
They can be considered as helper variables to account for the duration of the operational period as well as the total change within a representative period.
``\texttt{stor\_level\_Δ\_rp}`` is only declared if the `TimeStructure` includes `RepresentativePeriods`.
The application of `RepresentativePeriods` is explained in *[How to use TimeStruct.jl](@ref how_to-utilize_TS-struct-rp)*.

The variables ``\texttt{cap\_inst}``, ``\texttt{stor\_charge\_inst}``, ``\texttt{stor\_level\_inst}``, and ``\texttt{stor\_discharge\_inst}`` are used in `EnergyModelsInvestment` to allow for investments in capacity of individual nodes.

## [Flow variables](@id man-opt_var-flow)

Flow variables correspond to the input to and output from both technology nodes and links.
They are always positive to avoid backflow.

The following flow variables are defined for the nodes:

- ``\texttt{flow\_in}[n, t, p]`` represents the flow rate of resource ``p`` into node ``n`` at operational period ``t``. It is created for subtypes of the types [`NetworkNode`](@ref) and [`Sink`](@ref) based on the field `input` in the `composite type`.
- ``\texttt{flow\_out}[n, t, p]`` represents the flow rate of resource ``p`` out of node ``n`` at operational period ``t``. It is created for subtypes of the types [`Source`](@ref) and [`NetworkNode`](@ref) based on the field `output` in the `composite type`.

Links also have corresponding flow variables given by:

- ``\texttt{link\_in}[n, t, p]`` represents the flow rate of resource ``p`` into link ``l`` at operational period ``t``, and
- ``\texttt{link\_out}[n, t, p]`` represents the flow rate of resource ``p`` out of link ``l`` at operational period ``t``.

The resource index ``p`` is created based on the intersection of the output of the input node ``n_{in}`` and the input of the output node ``n_{out}`` through the function [`EMB.link_res(l::Link)`](@ref).
Mathematically, this is given as

``\mathcal{P}^{link} = \mathcal{P}^{n^{out}_{in}} \cap \mathcal{P}^{n^{in}_{out}}.``

It is also possible to create a new method for this function to limit the resources a link can transport.

## [Emission variables](@id man-opt_var-emissions)

Emission variables are used for accounting for emissions of the individual technologies.
Resources that can be emitted are defined through the type [`ResourceEmit`](@ref).
Nodes do not necessarily have associated emission variables.
Emission variables are only created for a node ``n`` if the function [`has_emissions(n::EMB.Node)`](@ref) returns `true`.
This is the case for all nodes that have [`EmissionsData`](@ref) within their field `data` as well as for a `RefStorage` node if a `ResourceEmit` is stored.
The following node variable is then declared for all emission resource 𝒫ᵉᵐ:

- ``\texttt{emissions\_node}[n, t, p_\texttt{em}]``:  Emissions of node ``n`` at operational period ``t`` of emission resource ``p_\texttt{em}``.

In addition, `EnergyModelsBase` declares the following variables for the global emissions:

- ``\texttt{emissions\_total}[t, p_\texttt{em}]``: Total emissions of `ResourceEmit` ``p_\texttt{em}`` in operational period ``t``, and
- ``\texttt{emissions\_strategic}[t_\texttt{inv}, p_\texttt{em}]``: Total emissions of `ResourceEmit` ``p_\texttt{em}`` in strategic period ``t_\texttt{inv}``.

These emission variables introduce limits on the total emissions of a resource through the field `emission_limit` of an `EnergyModel` in the function [`EMB.variables_emission`](@ref).

## [`Sink` variables](@id man-opt_var-sink)

`Sink` nodes are somehow different to the other nodes as they have additional variables associated with them.
A key point here is to keep the overall mass balance intact while allowing for both overfulfilling and not meeting the demand.
These variables are:

- ``\texttt{sink\_surplus}[n, t]``: Surplus of energy/mass to `Sink` ``n`` at operational period ``t``, and
- ``\texttt{sink\_deficit}[n, t]``: Deficit of energy/mass to `Sink` ``n`` at operational period ``t``.

The surplus in a sink corresponds to the energy/mass that is supplied to the sink in addition to the demand.
The deficit in a sink corresponds to the energy/mass that is not supplied to the sink although the demand is specified.
Both variables correspond to slack variables of the optimization problem.
They simplify the problem and can make certain types of formulations feasible.
It is possible to provide penalties for both surplus and deficits.
This is implemented through the field `penalty` in the [`RefSource`](@ref) node.

## [Node types and respective variables](@id man-opt_var-node)

As outlined in the introduction, `EnergyModelsBase` declares different variables for each `Node`.
These variables are for the individual nodes given in the subsections below.

### `Source`

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{cap\_use}``](@ref man-opt_var-cap)
- [``\texttt{cap\_inst}``](@ref man-opt_var-cap)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if `EmissionsData` is added to the field `data`

### `NetworkNode`, except for `Storage`

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{cap\_use}``](@ref man-opt_var-cap)
- [``\texttt{cap\_inst}``](@ref man-opt_var-cap)
- [``\texttt{flow\_in}``](@ref man-opt_var-flow)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if `EmissionsData` is added to the field `data`

### `Storage`

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@ref man-opt_var-opex)
- [``\texttt{stor\_level}``](@ref man-opt_var-cap)
- [``\texttt{stor\_level\_inst}``](@ref man-opt_var-cap)
- [``\texttt{stor\_charge\_use}``](@ref man-opt_var-cap)
- [``\texttt{stor\_charge\_inst}``](@ref man-opt_var-cap), if the `Storage` node has a field `:charge` with the `StorageParameters` corresponding to *[capacity storage parameters](@ref lib-pub-nodes-stor_par)*
- [``\texttt{stor\_discharge\_use}``](@ref man-opt_var-cap)
- [``\texttt{stor\_discharge\_inst}``](@ref man-opt_var-cap), if the `Storage` node has a field `:discharge` with the `StorageParameters` corresponding to *[capacity storage parameters](@ref lib-pub-nodes-stor_par)*
- [``\texttt{stor\_level\_Δ\_op}``](@ref man-opt_var-cap)
- [``\texttt{stor\_level\_Δ\_rp}``](@ref man-opt_var-cap) if the `TimeStruct` includes `RepresentativePeriods`
- [``\texttt{flow\_in}``](@ref man-opt_var-flow)
- [``\texttt{flow\_out}``](@ref man-opt_var-flow)
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if `ResourceEmit` is stored

### `Sink`

- [``\texttt{opex\_var}``](@ref man-opt_var-opex)
- [[``\texttt{opex\_fixed}``](@ref man-opt_var-opex)](@ref man-opt_var-opex)
- [``\texttt{cap\_use}``](@ref man-opt_var-cap)
- [``\texttt{cap\_inst}``](@ref man-opt_var-cap)
- [``\texttt{flow\_in}``](@ref man-opt_var-flow)
- [``\texttt{sink\_surplus}``](@ref man-opt_var-sink)
- [``\texttt{sink\_deficit}``](@ref man-opt_var-sink)
- [``\texttt{emissions\_node}``](@ref man-opt_var-emissions) if `EmissionsData` is added to the field `data`

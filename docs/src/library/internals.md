# Internals


## [`NonDisRES`](@ref)


## [`RegHydroStor`](@ref)

Since we also want to be able to model hydropower plant nodes *without* pumps, we include the boolean `Has_pump` in the struct describing hydropower. For combining the behavior of a dam with- and without a pump, we can disable the inflow of energy by setting the constraint

  ``\texttt{:flow\_in}[n, t, p_\texttt{stor}] = 0 \qquad \forall\, t \in \mathcal{T},``

for the stored resource ``p_\texttt{stor}`` `::Resource` for the node ``n`` `::RegHydroStor`. To acess this variable, we therefore have to let the struct `RegHydroStor` be a subtype of `EMB.Storage`. All fields and their type is listed in the struct documentation at [`RegHydroStor`](@ref).


## [Optimization variables](@id sec_lib_internal_opt_vars)

The only new optimization variable added by this package, is `:curtailment[n, t]` defined for all nodes ``n`` `::NonDisRes` and all ``t\in\mathcal{T}``. This is created by the method [`RenewableProducers.EMB.create_node`](@ref) which is a method called from `EnergyModelsBase`. The variable represents the amount of energy *not* produced by node ``n`` `::NonDisRes` at operational period ``t``. 

The variable is defined by the following constraint,

  ``\texttt{:cap\_use}[n, t] + \texttt{:curtailment}[n, t] = n.\texttt{Profile}[t] \cdot \texttt{:cap\_inst}[n, t] \qquad \forall\,t\in\mathcal{T},``

for all nodes ``n`` `::NonDisRES`.


## Methods

```@docs
RenewableProducers.EMB.variables_node
RenewableProducers.EMB.create_node
RenewableProducers.EMB.check_node
```
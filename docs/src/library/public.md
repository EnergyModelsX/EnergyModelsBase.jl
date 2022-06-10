# [Public interface](@id sec_lib_public)

## `NonDisRES` (non-dispatchable renewable source)

This struct models both wind power, solar power, and run of river hydropower. These have in common that they generate power from an intermittent energy source, so they can have large variations in power output, based on the availability of the renewable source at the time. These power sources are modelled using the same struct [`NonDisRES`](@ref). The new struct is a subtype of `EMB.Source`. The new struct only differs from its supertype with the field `Profile::TimeProfile`. 

The field `Profile::TimeProfile` is a dimensionless ratio (between 0 and 1) describing how much of the installed capacity is utilized at the current operational period. Therefore, when using [`NonDisRES`](@ref) to model some renewable source, the data provided to this field is what defines the intermittent characteristics of the source.

The [`NonDisRES`](@ref) node is modelled very similar to a regular `EMB.Source}` node. The only difference is how the intermittent nature of the non-dispatchable source is handled. The maximum power generation of the source in the operational period ``t`` depends on the time-dependent `Profile` variable. 

!!! note
    If not needed, the production does not need to run at full capacity. The amount of energy *not* produced is computed using the non-negative [optimization variable](@ref sec_lib_internal_opt_vars) `:curtailment` (declared for [`NonDisRES`](@ref) nodes only).


## `RegHydroStor` (regulated hydro storage)

A hydropower plant is much more flexible than, e.g., a wind farm since the water can be stored for later use. Energy can be produced (almost) whenever it is needed. Some hydropower plants also have pumps installed. These are used to pump water into the reservoir when excess and cheap energy is available in the network. A hydropower plant thus resembles both a `EMB.Source` and a `EMB.Storage`. 

The field `Capacity` describes the installed capacity of the (aggregated) hydropower plant. The variable `Level_init` represents the initial energy available in the reservoir in the beginning of each investment period, while `Stor_cap` is the installed storage capacity in the reservoir. The variable `Level_inflow` describes the inflow into the reservoir (measured in energy units), while `Level_min` is the allowed minimum storage level in the dam, given as a ratio of the installed storage capacity of the reservoir at every operational period. The required minimum level is enforced by NVE and varies over the year.

!!! note 
    The four last variables are mostly used in the same way as in `EMB.Storage`, the only difference is the `Input` and `Output` variables. In a `EMB.Storage`, the resource ``p`` with a value of 1 is registered as the stored resource. In the implementation of [`RegHydroStor`](@ref), it was desirable to use this value to model a loss of energy when using the pumps. We therefore need to allow that the stored resource ``p_\texttt{stor}`` has values less than 1 (but non-negative) in the `Input` dictionary.

    Therefore, we use the `output` variable for registering what resource is stored. Since the program only allows one entry here, only the resource used as key needs to be checked to determine this.


## [Documentation](@id sec_lib_public_docs)

```@docs
RenewableProducers
NonDisRES
RegHydroStor
```

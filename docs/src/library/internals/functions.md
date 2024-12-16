# [Internal functions](@id lib-int-fun)

## [Index](@id lib-int-fun-idx)

```@index
Pages = ["functions.md"]
```

```@meta
CurrentModule = EnergyModelsBase
```

## [Extension functions](@id lib-int-fun-ext)

```@docs
create_link
objective(m, 𝒳, 𝒫, 𝒯, modeltype::EnergyModel)
objective_operational
emissions_operational
```

## [Constraint methods](@id lib-int-fun-con)

```@docs
constraints_emissions
constraints_links
constraints_node
constraints_level_iterate
constraints_level_rp
constraints_level_scp
constraints_level_bounds
```

## [Variable creation functions](@id lib-int-fun-var)

```@docs
variables_capacity
variables_flow
variables_opex
variables_capex(m, 𝒩::Vector{<:Node}, 𝒯, modeltype::EnergyModel)
variables_emission
variables_elements
```

## [Check functions](@id lib-int-fun-check)

```@docs
check_data
check_case_data
check_model
check_node
check_node_default
check_fixed_opex
check_node_data(n::Node, data::EmissionsData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
check_time_structure
check_profile
check_strategic_profile
check_representative_profile
check_scenario_profile
compile_logs
```

## [Identification functions](@id lib-int-fun-identi)

```@docs
is_network_node
is_sink
is_source
is_storage
is_resource_emit
has_charge_OPEX_fixed
has_charge_OPEX_var
has_charge_cap
has_discharge_OPEX_fixed
has_discharge_OPEX_var
has_discharge_cap
has_level_OPEX_fixed
has_level_OPEX_var
nodes_not_av
nodes_not_sub
nodes_sub
link_res
link_sub
res_em
res_not
res_sub
```

## Miscellaneous functions

```@docs
collect_types
sort_types
```

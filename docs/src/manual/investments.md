# [Adding investments](@id man-emi)

Investment options are added through loading the package [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/).
`EnergyModelsInvestments` was previously seen as extension package to `EnergyModelsBase`, that it was dependent on `EnergyModelsBase` and only allowed investment options in `EnergyModelsBase`.
This approach was reversed from version 0.7 onwards and `EnergyModelsInvestments` is now a standalone package and provides an extension to `EnergyModelsBase`.

## [General concept](@id man-emi-gen)

Investment options are added separately to each individual node through the field `data`.
Hence, it is possible to use different prices for the same technology in different regions or allow investments only in a limited subset of technologies.

We differentiate between [`SingleInvData`](@ref) and [`StorageInvData`](@ref).
Both types inlude as fields [`AbstractInvData`](@extref EnergyModelsInvestments.AbstractInvData) which can be either in the form of [`StartInvData`](@extref EnergyModelsInvestments.StartInvData) or [`NoStartInvData`](@extref EnergyModelsInvestments.NoStartInvData).
The exact description of the individual investment data and their fields can be found in the *[public library](@extref EnergyModelsInvestments lib-pub)* of `EnergyModelsInvestments`.

Investments require the application of an [`InvestmentModel`](@ref) instead of an [`OperationalModel`](@ref).
This allows us to provide two core functions with new methods, `constraints_capacity_installed` (as described on *[Constraint functions](@ref man-con)*), `variables_capex`, a function previously not declaring any variables, and the function `objective` for declaring the objective function.

## [Added variables](@id man-emi-var)

Investment options increase the number of variables.
The individual variables are described in the *[documentation of `EnergyModelsInvestments`](@extref EnergyModelsInvestments man-opt_var)*.

All nodes (except `Storage` nodes) with investments use the prefix `:cap`.
`Storage` nodes utilize the prefices `:stor_level` for level capacity investments, `:stor_charge` for storage charging capacity investments, and `:stor_discharge` for storage discharge capacity investments.
`Storage` nodes only include these variables if they have the investment potential for the individual capacities.

!!! tip "Differentiation in capacity investments of Storage nodes"
    Storage nodes have in general the possibility to allow for investments in all individual capacities or only a subset of capacities.
    However, we do not consider a discharge capacity for a `RefStorage` node as it is as simple as possible.
    Hence, it is possible to discharge a `RefStorage` node within an operational period.

    Although we include the potential for investments in both the charge and level capacities, we do not enforce that you include investment data for both capacities.
    Hence, it is entirely up to the user to specify whether he wants to include, *e.g.*, an unlimited charge capacity and only investments in the level capacity, or a fixed level capacity and investments in charge capacities, or any combination.

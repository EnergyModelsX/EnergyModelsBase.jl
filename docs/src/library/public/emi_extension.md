# [`EnergymodelsInvestments` extensions](@id lib-pub-emi_ext)

The extension introduces new types and functions.
These are create within the core structure, as it is not possible to export new types/functions from extensions.
In this case, we use constructors within the extension for the abstract types declared within the core structure.

The following page provides you with an overview of the individual constructors.
The described fields are only available if you load `EnergyModelsInvestments` as well.

## [`AbstractInvestmentModel`](@id lib-pub-emi_ext-types)

Including the extension for [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) results in the declaration of the types `AbstractInvestmentModel` and `InvestmentModel` which can be used for creating models with investments
It takes as additional input the `discount_rate`.
The `discount_rate` is an important element of investment analysis needed to represent the present value of future cash flows.
It is provided to the model as a value between 0 and 1 (*e.g.* a discount rate of 5 % is 0.05).

```@docs
AbstractInvestmentModel
InvestmentModel
```

## [Functions for accessing fields of `AbstractInvestmentModel` types](@id lib-pub-fun_field_model)

The current implementation extracts the discount rate through a function.

!!! warning
    If you want to introduce new `AbstractInvestmentModel` types, you have to in additional consider the function `discount_rate`.

```@docs
discount_rate
```

## [Investment data](@id lib-pub-emi_ext-inv_data)

### [`InvestmentData` types](@id lib-pub-emi_ext-inv_data-types)

`InvestmentData` subtypes are used to provide technologies introduced in `EnergyModelsX` (nodes and transmission modes) a subtype of `Data` that can be used for dispatching.
Two different types are directly introduced, `SingleInvData` and `StorageInvData`.

`SingleInvData` is providing a composite type with a single field.
It is used for investments in technologies with a single capacity, that is all nodes except for storage nodes as well as tranmission modes.

`StorageInvData` is required as `Storage` nodes behave differently compared to the other nodes.
In `Storage` nodes, it is possible to invest both in the charge capacity for storing energy, the storage capacity, that is the level of a `Storage` node, as well as the discharge capacity, that is how fast energy can be withdrawn.
Correspondingly, it is necessary to have individual parameters for the potential investments in each capacity, that is through the fields `:charge`, `:level`, and `:discharge`.

```@docs
InvestmentData
SingleInvData
StorageInvData
```

### [Legacy constructors](@id lib-pub-emi_ext-inv_data-leg)

We provide a legacy constructor, `InvData` and `InvDataStorage`, that use the same input as in version 0.5.x.
If you want to adjust your model to the latest changes, please refer to the section *[Update your model to the latest version of EnergyModelsInvestments](@extref EnergyModelsInvestments how_to-update-05)*.

```@docs
InvData
InvDataStorage
```

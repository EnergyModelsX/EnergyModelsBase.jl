# Release notes

## Unversioned

### Major rework of input data structure

* Set links and nodes as subtype of a new `AbstractElement` type.
* Moved from a dictionary to a type called `Case`.
* The type allows extensions without having to create a new `create_model` function, and hence, run in potential problems with several extensions packages.

### Minor updates

* Allow for checks for links.

## Version 0.8.3 (2024-11-29)

### Reference checks possible to be called

* Created function `check_node_default()`.
* The function can be called from other `check_node` to include all default checks

## Version 0.8.2 (2024-11-27)

### Restructuring of function calls

* Restructured function flow for variable and constraint.
* Allows extension with new types that we have not yet considered for the cost function and the emissions.

### Incorporation of bidirectional flow

* Allow (in theory) for nodes and links with bidirectional flow through avoiding hard-coding a lower bound on flow variables.
* No existing links and nodes allow for bidirectional flow.
* Bidirectional flow requires new links and nodes with new methods for the function `is_unidirectional`.

### Rework of links

* Extended the functionality of links significantly.
* Allow for
  * differing input and output resources of links as well as specifying these directly,
  * emissions of links,
  * OPEX of links (with both fixed and variable OPEX created at the same time),
  * capacity of links,
  * inclusion of specific link variables, and
  * investments in links if the links have a capacity.
* The majority of changes are incorporated through filter functions and require the user to define new methods for the included functions (*i.e.*, `has_opex`, `has_emissions`, and `has_capacity`)
* Inclusion of variables follows principle of additional node variables.

### Minor updates

* Updated som docstrings.
* Updated some minor changes in the documentation.

## Version 0.8.1 (2024-10-16)

### Bugfixes

* Fixed a bug in which it was possible to have wrong profiles if it must be indexed over an operational scenario or representative period.

### Adjustment to EnergyModelsInvestments changes

* Adjusted the investment data checks.
* Provided legacy constructors for the previous usage of `SingleInvData`.
* Introduced the investment examples to the example sections.
* Added investment options tests.

### Rework of documentation

* The documentation received a significant rework.
  The rework consists of:
  * Providing webpages for the individual nodal descriptions in which the fields are described more in detail as well as a description of the constraints of the individual nodes.
  * Restructured both the public and internal libraries

### Minor updates

* Included an option to deactive the checks entirely with printing a warning.
* Introduced the variable ``\texttt{stor\_level\_Δ\_sp}`` using `SparseVariables` to simplify the extension in other `Storage` nodes.
* Replaced the function `EMB.multiple` with the function `scale_op_sp` to avoid issues with respect to a function of the same name in `TimeStruct`.
  * This type is now exported, simplifying its application in other packages.
  * `EMB.multiple` is still included through a deprecation notice. It is however advisable to switch to the new function.

## Version 0.8.0 (2024-08-20)

### Introduced `EnergyModelsInvestments` as extension

* `EnergyModelsInvestments` was switched to be an independent package in [PR #28](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/pull/28).
* This approach required `EnergyModelsBase` to include all functions and type declarations internally.
* An extension was introduced to handle these problems.

### Minor updates

* Updated minor issues in the documentation (docstrings, indices, and quick start).
* Use dev version of EMB for examples when running as part of tests, solving [Issue #17](https://github.com/EnergyModelsX/EnergyModelsBase.jl/issues/17).
* Naming of the total emission constraint to allow for updates in the coefficients in other packages.

## Version 0.7.0 (2024-05-24)

### Introduction of `AbstractStorageParameters` type for increasing potential for `Storage` variations

* Introduced a `:discharge` capacity for `Storage` nodes in addition to the existing capacities.
* `AbstractStorageParameters` type allows for `Storage` capacities (`:charge`, `:level`, and `:discharge`) to include a capacity, variable OPEX, and or fixed OPEX.
* This increases the flexibility for `Storage` node utilization.

### Introduction of `StorageBehavior` type for reusability of level balances

* Introduction of `CyclicRepresentative` behavior with support for `OperationalScenarios`.
  In this `StorageBehavior`, the accumulation within a representative period is set to 0.
* Change in `Storage{AccumulatingEmissions}` to avoid requiring a capacity when only emissions are present.

### Checks

* Do not print a warning, when using `OperationalProfile` with a time structure containing `RepresentativePeriods`.

## Version 0.6.8 (2024-04-18)

* Added potential for negative emissions.
  This change requires the user to always constrain the variable `emissions_node`, if it is defined by the user.
  By default, this is achieved in the developed packages through `EmissionsData` or the addition of additional bounds on
  the variable `:emissions_node` through the JuMP function [`set_lower_bound`](https://jump.dev/JuMP.jl/stable/api/JuMP/#set_lower_bound).
* Provided a contribution section in the documentation.
* Minor changes in the naming convention in the documentation.
* Removed `\texttt{}` from docstrings.

## Version 0.6.7 (2024-03-21)

* Allow for deactivation of timeprofile checks while printing a warning in this case.
* Fixed a bug for a too short `StrategicProfile` in the checks.
* Added checks for the case dictionary.
* Extended checks for the modeltype.
* Added functions that can be used to check whether a `TimeProfile` can be indexed over `StrategicPeriod`s, `RepresentativePeriod`s, or `OperationalScenario`s.

## Version 0.6.6 (2024-03-04)

### Examples

* Fixed a bug when running the examples from a non-cloned version of `EnergyModelsBase`.
* This is achieved through a separate Project.toml in the examples folder.

### Checks

* Fixed the bug preventing the time profile checks to run.
* Included checks of the input data and for all nodes.
* Included tests for checks.

### Minor updates

* Added functions `inputs`, `outputs`, and `data_nodes` for `Availability` and `outputs` for `Source` nodes.
* Allow availability to not require all resources in the the `input` and `output` field.
* Moved all files declaring structures to a separate folder for improved readability.
* Reworked the structure of the test folder.

## Version 0.6.5 (2024-01-31)

* Updated the restrictions on the fields of individual types to be consistent.

## Version 0.6.4 (2024-01-18)

* Minor modification to the `EmissionsData` allowing now also time dependent process emissions.
* This is achieved through switching to a parametric type.

## Version 0.6.3 (2024-01-17)

* Changed name of `constraints_level`  to `constraints_level_sp` when the time input is given as a `StrategicPeriod` to improve understandability.
* Add `modeltype::EnergyModel` as an argument to the methods `constraints_level_sp` (see above) and `constraints_level_aux`.

## Version 0.6.2 (2024-01-17)

* When variables are created with the method `variables_nodes`, it will lead to an `ErrorException` when the method tries to create a variable that has already been created. This is ok, and this error should be ignored. This change specifies exactly what error should be ignored, to avoid that other types of errors are also ignored.

## Version 0.6.1 (2024-01-11)

* Fix: add missing parenthesis in the objective function.

## Version 0.6.0 (2023-12-14)

* Switched fields `Input` and `Output` of `Availability` nodes from `Dict{Resource, Real}` to `Array{<:Resource}`. The former is still available as a constructor, while a new constructor is introduced which requires the input only once.
* All fields in composite types are now lower case.
* Renamed `Network` to `NetworkNode`. `NetworkNode` can be considered to be replaced in a later iterations as it is not really needed.
* Added functions for extracting the fields of `Node`s, `Resource`s, and `EnergyModel`s to allow for extensions.
* Added export of functions that are frequently used in other packages.
* Moved the emissions to a `Data` type on which we can dispatch, depending on the chosen approach for capture and process emissions.
* Redesigned storage as parametric type to dispatch on the level balance. This includes as well the introduction of a new variable.
* Included potential for different durations of operational periods.
* Included representative periods. These do only affect a `Storage` node as these are the only time dependent nodes.
* Added emission prices to `OperationalModel`.

## Version 0.5.2 (2023-11-06)

* Introduced method `create_model` that can take a `JuMP.Model` as input to simplify potential use of other type of models
* Fixed the documentation to avoid errors

## Version 0.5.1 (2023-06-16)

* Updated the documentation based on the new format

## Version 0.5.0 (2023-06-01)

### Switch to TimeStruct.jl

* Switched the time structure representation to [TimeStruct.jl](https://sintefore.github.io/TimeStruct.jl/)
* TimeStruct.jl is implemented with only the basis features that were available in TimesStructures.jl. This implies that neither operational nor strategic uncertainty is included in the model

## Version 0.4.0 (2023-05-30)

### Additional input data changes

* Changed the structure in which the extra field `Data` is included in the nodes
* It is changed from `Dict{String, Data}` to `Array{Data}`

## Version 0.3.3 (2023-04-26)

* Changed where storage variables are declared to avoid potential method ambiguity through new storage variables when using `EnergyModelsInvestments`

## Version 0.3.2 (2023-02-07)

* Generalized the function names for identifying and sorting the individual introduced types.

## Version 0.3.1 (2023-02-03)

* Take the examples out to the directory `examples`

## Version 0.3.0 (2023-02-02)

### Fields of reference types and new types

* Removal of all process emissions and CO₂ capture from reference types to avoid having to include them as well
in all subtypes defined later to keep the fallback option. This requires in the future to***remove*** CO₂ as output when using CO₂ capture as it was previously the case. The original types are retained so that they can still be used
* Introduction of a type `RefStorageEmissions` to account for a storage unit that can be used for storing `ResourceEmit`

### Introduction of functions for constraints generation

* Substitution of variable and fixed OPEX calculations as well as capacity and flow constraints through functions which utilize dispatching on `node` types

### Redefinition of introduction of global data

* Removal of the type `AbstractGlobalData` and all subtypes and substitution through `EnergyModel` and the corresponding subtypes
* Addition of the field `CO2_instance` in the type `OperationalModel`
* Addition of `ModelType` to the function `create_node` to be able to use different ids for the CO₂ resource

### Additional changes

* Redefining `CO2Int` in fields of type `Resource` to `CO2_int` to be consistent with the other types
* Minor changes in constraint description that do not break previous code
* Changed the input to the function `variables_node` to simplify the generation of variables for a specific `node` type

## Version 0.2.7 (2022-12-12)

### Internal release

* Renamed packages to use common prefix
* Updated README

## Version 0.2.4 (2022-09-07)

### Feature update and changes in export

* Inclusion of time dependent profiles for surplus and deficit of sinks
* Inclusion of parameter checks for surplus and deficit of sinks
* Export of all reference nodes for easier identification of the nodes
* Changes in the test structure with improved testing of variables
* Changes in doc strings for individual functions/types

## Version 0.2.3 (2021-09-07)

### Changes in naming

* Major changes in both variable and parameter naming, check the commit message for an overview

## Version 0.2.2 (2021-08-20)

### Feature updates

* Change of Availability to abstract type and introduction of GenAvailability
  as composite type to be able to use multiple dispatch on the availability nodes
* Inclusion of the entry fixed OPEX to the node composite types
* Inclusion of the entry data to the node composite types to provide input
  required for certain additional packages like investments
* New function for checks of node data so that we have an a priori check of all
  model data

### Changes in naming

* Introduce the optimization variables stor_level and stor_max for storages, and
  use these instead of cap_usage and cap_max for the constraints on Storage.
* Use the new variable cap_storage in Storage nodes for the installed storage capacity.

## Version 0.2.1 (2021-04-22)

### Feature updates

* Reduction in variables through introduction of input/output (#2)
dictionaries for all nodes that only include necessary components
* Improvement related to emissions to avoid wrong accounting when other emission carriers than CO₂ are present (#2)
* Link resources generated automatically from input (#2)

### Changes in naming

* Removal of prefix "create" before "constraints" and "variables"
* "create_module" switched to "create_node"

## Version 0.2.0 (2021-04-19)

* Inclusion of abstract type and structures for both resources and (#1)
differentiation in nodes
* Development of new functions for the given data structures to obtain (#1)
subsets of the system
* Development of the core structure in model.jl for allowing variations (#1)
in the different nodes
* Implementation of fallback solutions for source, network, storage,
and sink (#1)
* Inclusion of availability node for easier distribution of energy in a
single geographical node and transfer from one geographical node to the
next (#1)
* Providing a test case that can be used for playing around with the simple
system (#1)

## Version 0.1.0 (2021-03-19)

* Initial (skeleton) version

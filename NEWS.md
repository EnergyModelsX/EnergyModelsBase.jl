# Release notes

Version 0.5.1 (2023-06-16)
--------------------------
 * Updated the documentation based on the new format

Version 0.5.0 (2023-06-01)
--------------------------
### Switch to TimeStruct.jl
 * Switched the time structure representation to [TimeStruct.jl](https://gitlab.sintef.no/julia-one-sintef/timestruct.jl)
 * TimeStruct.jl is implemented with only the basis features that were available in TimesStructures.jl. This implies that neither operational nor strategic uncertainty is included in the model

Version 0.4.0 (2023-05-30)
--------------------------
### Additional input data changes
 * Changed the structure in which the extra field `Data` is included in the nodes
 * It is changed from `Dict{String, Data}` to `Array{Data}`

Version 0.3.3 (2023-04-26)
--------------------------
 * Changed where storage variables are declared to avoid potential method ambiguity through new storage variables when using `EnergyModelsInvestments`

Version 0.3.2 (2023-02-07)
--------------------------
 * Generalized the function names for identifying and sorting the individual introduced types.

Version 0.3.1 (2023-02-03)
--------------------------
 * Take the examples out to the directory `examples`

Version 0.3.0 (2023-02-02)
--------------------------
### Fields of reference types and new types
* Removal of all process emissions and CO2 capture from reference types to avoid having to include them as well
in all subtypes defined later to keep the fallback option. This requires in the future to ***remove*** `CO2` as output when using CO2 capture as it was previously the case. The original types are retained so that they can still be used
* Introduction of a type `RefStorageEmissions` to account for a storage unit that can be used for storing `ResourceEmit`

### Introduction of functions for constraints generation
* Substitution of variable and fixed OPEX calculations as well as capacity and flow constraints through functions which utilize dispatching on `node` types

### Redefinition of introduction of global data
* Removal of the type `AbstractGlobalData` and all subtypes and substitution through `EnergyModel` and the corresponding subtypes
* Addition of the field `CO2_instance` in the type `OperationalModel`
* Addition of `ModelType` to the function `create_node` to be able to use different ids for the `CO2` resource

### Additional changes
* Redefining `CO2Int` in fields of type `Resource` to `CO2_int` to be consistent with the other types
* Minor changes in constraint description that do not break previous code
* Changed the input to the function `variables_node` to simplify the generation of variables for a specific `node` type

Version 0.2.7 (2022-12-12)
--------------------------
### Internal release
* Renamed packages to use common prefix
* Updated README

Version 0.2.4 (2022-09-07)
--------------------------
### Feature update and changes in export
* Inclusion of time dependent profiles for surplus and deficit of sinks
* Inclusion of parameter checks for surplus and deficit of sinks
* Export of all reference nodes for easier identification of the nodes
* Changes in the test structure with improved testing of variables
* Changes in doc strings for individual functions/types

Version 0.2.3 (2021-09-07)
--------------------------
### Changes in naming
* Major changes in both variable and parameter naming, check the commit message for an overview

Version 0.2.2 (2021-08-20)
--------------------------
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

Version 0.2.1 (2021-04-22)
--------------------------
### Feature updates
* Reduction in variables through introduction of input/output (#2)
dictionaries for all nodes that only include necessary components
* Improvement related to emissions to avoid wrong accounting when other emission carriers than CO2 are present (#2)
* Link resources generated automatically from input (#2)

### Changes in naming
* Removal of prefix "create" before "constraints" and "variables"
* "create_module" switched to "create_node"

Version 0.2.0 (2021-04-19)
--------------------------
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

Version 0.1.0 (2021-03-19)
--------------------------
* Initial (skeleton) version
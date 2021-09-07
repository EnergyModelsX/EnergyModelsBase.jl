# EnergyModelsBase changelog

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
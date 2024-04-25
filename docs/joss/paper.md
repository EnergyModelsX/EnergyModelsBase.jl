---
title: 'EnergyModelsX: Flexible Energy Systems Modelling with Multiple Dispatch'
tags:
  - Julia
  - energy
  - multi-carrier
  - multiple dispatch
authors:
  - name: Lars Hellemo
    orcid: 0000-0001-5958-9794
    equal-contrib: true
    corresponding: true # (This is how to denote the corresponding author)
    affiliation: 1
  - name: Espen Flo Bødal
    orcid: 0000-0001-6970-9315
    equal-contrib: true
    affiliation: 2
  - name: Sigmund Eggen Holm
    orcid: 0009-0007-1782-6326
    equal-contrib: true
    affiliation: 2
  - name: Dimitri Pinel
    orcid: 0000-0001-9393-0036
    equal-contrib: true
    affiliation: 2
  - name: Julian Straus
    orcid: 0000-0001-8622-1936
    equal-contrib: true
    affiliation: 2
affiliations:
 - name: SINTEF Industry, Postboks 4760 Torgarden, 7465 Trondheim
   index: 1
 - name: SINTEF Energy Research, Postboks 4761 Torgarden, 7465 Trondheim
   index: 2

date: 8 March 2024
bibliography: paper.bib

---

# Summary

[EnergyModelsX](https://github.com/EnergyModelsX/) is a multi-nodal energy system modelling framework written in Julia [@bezanson2017julia], based on the mathematical programming DSL JuMP [@Lubin2023].
The framework is designed to be flexible and easy to extend, for instance all resources, both energy carriers and materials, may be defined by the user.
Furthermore, EnergyModelsX follows a modular design to facilitate extensions through additional packages.
[EnergyModelsX](https://github.com/EnergyModelsX/) was developed at the Norwegian research organization [SINTEF](https://www.sintef.no/en) at the institutes SINTEF Energi and SINTEF Industri.
The framework consists of the package EnergyModelsBase and currently provides the following extensions: EnergyModelsGeography, EnergyModelsInvestments and EnergyModelsRenewableProducers.

See @bodal2024hydrogen for an example application of `EnergyModelsX`.

# Statement of need

The increasing share of renewable energy generation and importance of sector coupling increases the complexity of energy systems, and makes the modelling of these systems more challenging.
To meet the demand of energy modelers, energy system models need ever increasing flexibility to analyse the energy systems of tomorrow [@fodstad2022next].
While large scale models like TIMES [@times] and GENeSYS-MOD [@genesysmod] are important for modelling large energy systems, they lack the potential for simple modifications in technology descriptions as well as simple incorporation of region specific constraints.
[SpineOpt](https://github.com/spine-tools/SpineOpt.jl/tree/master) [@SpineOpt] offers the user with the flexibility, but the monolithic approach of including all functionality in a single package reduces the understandability of the code. [GenX](https://github.com/GenXProject/GenX.jl) [@GenX] and [Tulipa Energy Model](https://github.com/TulipaEnergy/TulipaEnergyModel.jl) [@Tulipa] are other recent energy system models developed in Julia with similar goals to EnergyModelsX, but with less focus on extensibility and alternative technology formulations.  

[EnergyModelsX](https://github.com/EnergyModelsX/) is a modular energy-system modelling framework designed to give modelers a high level of flexibility.
The time resolution is decoupled from the technology descriptions by the application of [TimeStruct](https://github.com/sintefore/TimeStruct.jl) [@TimeStruct], facilitating the support of a wide range of time structures with different temporal resolution and to support operational uncertainty.
The system is designed from the ground up to support multiple energy carriers, and the modeler may define resources, including energy carriers, materials and emissions freely.
The base model is designed to allow extentions with extra functionality such as support for different spatial resolution or more detailed technology description, making the framework well suited to address the needs of modelling integrated energy systems with sector coupling.

State-of-the art modelling frameworks have several limitations; they are often built on proprietary algebraic modelling languages with parameter-driven models and often start from a single energy-carrier.
[EnergyModelsX](https://github.com/EnergyModelsX/) addresses these shortcomings by using the modern modelling framework JuMP with excellent performance characteristics.
Modularity is achieved through Julia's multiple dispatch functionality, allowing extensions to build on the base package.
The results can be made fully reproducible by using an open modelling language and the Julia package manager for simple reproducibility of analyses.

With a fast and flexible system, users and developers may iterate rapidly, develop new or modify existing functionalities to adjust analyses to their needs and run multiple sensitivity analyses with ease.

# Released packages of EnergyModelsX

As part of the initial release of [EnergyModelsX](https://github.com/EnergyModelsX/), the following packages and extensions are available:

## EnergyModelsBase

[EnergyModelsBase](https://github.com/EnergyModelsX/EnergyModelsBase.jl) is the base model, providing an optimal dispatch model for operational analyses of local systems.
Reference (linear) implementations are available for a set of different generic node types, including Source (only output), NetworkNode (input and output) and Sink (only input), as well as Availability nodes to serve as a connector, and Storage.
EnergyModelsBase is designed to be extendable without changes to the core structure.
It provides abstract types that may be extended by additional packages for more specific nodes such that more detailed technology modelling can be applied easily.
This allows keeping the size of EnergyModelsBase to a minimum, reducing both the difficulty of understanding the modelling approach and the compilation time.

## EnergyModelsGeography

[EnergyModelsGeography](https://github.com/EnergyModelsX/EnergyModelsGeography.jl) extends EnergyModelsBase with modelling of geographical regions with transmission capacity between regions.
Different modes of transmission are provided, allowing to model e.g. power transmission lines and pipelines.
EnergyModelsGeography follows the same philosophy as EnergyModelsBase.
Hence, users can easily develop new descriptions of transmission modes or special restrictions on regions.

## EnergyModelsInvestments

To support capacity expansion models, [EnergyModelsInvestments](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl) allows adding investment decisions to add or increase installed capacity for nodes.
The investments can be modelled using a variety of investment modes, including discrete, continuous or semi-continuous.
The modeler has full flexibility and may combine available investment modes as best fits the problem at hand, while EnergyModelsInvestments will make sure to only add the needed (binary) variables and constraints for each node or link.

## EnergyModelsRenewableProduction

[EnergyModelsRenewableProducers](https://github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl) facilitates the modelling of renewable energy generation, both from non-dispatchable technologies such as wind power and PV and for hydropower with (pumped) storage.
It also serves as an example for introducing new technology descriptions to EnergyModelsX and how to reuse constraints of the reference nodes.

# Example application

To illustrate the usage of EnergyModelsX, consider the example on a North Sea Region for the development of hydrogen infrastructure. The example highlights the potential of multiple regions with different technologies as well as the implementation of different investment options, both for pipelines and technology nodes. Pipeline costs take economies of scale into account. See also @bodal2024hydrogen for a similar example.

![Example application: hydrogen infrastructure development in the North Sea region](figure_1.pdf)

# Acknowledgements

The development of `EnergyModelsX` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811).
The authors gratefully acknowledge the financial support from the user partners: Å Energi, Air Liquide, Equinor Energy, Gassco, and Total OneTech.

# References

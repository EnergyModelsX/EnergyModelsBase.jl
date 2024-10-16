# EnergyModelsBase

[![DOI](https://joss.theoj.org/papers/10.21105/joss.06619/status.svg)](https://doi.org/10.21105/joss.06619)
[![Build Status](https://github.com/EnergyModelsX/EnergyModelsBase.jl/workflows/CI/badge.svg)](https://github.com/EnergyModelsX/EnergyModelsBase.jl/actions?query=workflow%3ACI)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/)
[![In Development](https://img.shields.io/badge/docs-dev-blue.svg)](https://energymodelsx.github.io/EnergyModelsBase.jl/dev/)

`EnergyModelsBase` is the core package for building flexible multi-energy-carrier energy systems models.
It is designed to model the basic operations of various generation, conversion and storage technologies.
`EnergyModelsBase` is designed to enable optimization of operations, and to be be easily extendible to investment models, and/or to include new technologies or more detailed models of key technologies.

## Error in stable documentation

The stable documentation (based on the registered version) has currently the following error.
In the description of the variables, we wrote in the [Section on capacity variables](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/manual/optimization-variables/#man-opt_var-cap):

```julia
for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ˢᵘᵇ
    insertvar!(stor_level_Δ_sp, n, t_inv)
end
```

The correct solution is

```julia
for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ˢᵘᵇ
    insertvar!(m[:stor_level_Δ_sp], n, t_inv)
end
```

## Usage

The usage of the package is best illustrated through the commented [`examples`](examples).
The examples are minimum working examples highlighting how to build simple energy system models.

## Cite

If you find `EnergyModelsBase` useful in your work, we kindly request that you cite the following [publication](https://doi.org/10.21105/joss.06619):

```bibtex
@article{hellemo2024energymodelsx,
  title={EnergyModelsX: Flexible Energy Systems Modelling with Multiple Dispatch},
  author={Hellemo, Lars and B{\o}dal, Espen Flo and Holm, Sigmund Eggen and Pinel, Dimitri and Straus, Julian},
  journal={Journal of Open Source Software},
  volume={9},
  number={97},
  pages={6619},
  year={2024}
}
```

For earlier work, see our [paper in Applied Energy](https://www.sciencedirect.com/science/article/pii/S0306261923018482):

```bibtex
@article{boedal_2024,
  title = {Hydrogen for harvesting the potential of offshore wind: A {N}orth {S}ea case study},
  journal = {Applied Energy},
  volume = {357},
  pages = {122484},
  year = {2024},
  issn = {0306-2619},
  doi = {https://doi.org/10.1016/j.apenergy.2023.122484},
  url = {https://www.sciencedirect.com/science/article/pii/S0306261923018482},
  author = {Espen Flo B{\o}dal and Sigmund Eggen Holm and Avinash Subramanian and Goran Durakovic and Dimitri Pinel and Lars Hellemo and Miguel Mu{\~n}oz Ortiz and Brage Rugstad Knudsen and Julian Straus}
}
```

## Project Funding

The development of `EnergyModelsBase` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)

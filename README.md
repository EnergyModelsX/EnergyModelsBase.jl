# EnergyModelsBase

`EnergyModelsBase` is the core package to building flexible multi-energy-carrier energy systems models.
It is designed to model the basic operations of various generation, conversion and storage technologies.
`EnergyModelsBase` is designed to enable optimization of operations, and to be be easily extendible to investment models, and/or to include new technologies or more detailed models of key technologies.

> **Note**
> We migrated recently from an internal Git solution to GitHub, including the package [`TimeStruct`](https://github.com/sintefore/TimeStruct.jl). As `TimeStruct` is not yet registered, it is not possible to build automatically the documentation or run the tests without significant changes in the CI. Every user is however free to build the documentation from the [`docs`](docs) folder.

## Usage

The documentation for `EnergyModelsBase` is currently not available as we migrated recently to GitHub.
Once `TimeStruct` is registered in the Julia Registry, we will update the README.md  and add the links to the documentation.

See examples of usage of the package and a simple guide for running them in the folder [`examples`](examples).

## Cite

If you find `EnergyModelsBase` useful in your work, we kindly request that you cite the following publication:

```@article{boedal_2024,
  title = {Hydrogen for harvesting the potential of offshore wind: A North Sea case study},
  journal = {Applied Energy},
  volume = {357},
  pages = {122484},
  year = {2024},
  issn = {0306-2619},
  doi = {https://doi.org/10.1016/j.apenergy.2023.122484},
  url = {https://www.sciencedirect.com/science/article/pii/S0306261923018482},
  author = {Espen Flo Bødal and Sigmund Eggen Holm and Avinash Subramanian and Goran Durakovic and Dimitri Pinel and Lars Hellemo and Miguel Muñoz Ortiz and Brage Rugstad Knudsen and Julian Straus}
}
```

## Project Funding

The development of `EnergyModelsBase` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)

# Quick Start

>  1. Install the most recent version of [Julia](https://julialang.org/downloads/)
>  2. Add the [CleanExport internal Julia registry](https://gitlab.sintef.no/clean_export/registrycleanexport):
>     ```
>     ] registry add git@gitlab.sintef.no:clean_export/registrycleanexport.git
>     ```
>  3. Add the [SINTEF internal Julia registry](https://gitlab.sintef.no/julia-one-sintef/onesintef):
>     ```
>     ] registry add git@gitlab.sintef.no:julia-one-sintef/onesintef.git
>     ```
>  4. Install the base package [`EnergyModelsBase.jl`](https://clean_export.pages.sintef.no/energymodelsbase.jl/) and the time package [`TimeStruct.jl`](https://gitlab.sintef.no/julia-one-sintef/timestruct.jl), by running:
>     ```
>     ] add EnergyModelsBase
>     ] add TimeStruct
>     ```
>     This will fetch the packages from the CleanExport package and OneSINTEF registries.
# Quick Start

>  1. Install the most recent version of [Julia](https://julialang.org/downloads/)
>  2. Add the [CleanExport internal Julia registry](https://gitlab.sintef.no/clean_export/registrycleanexport):
>     ```
>     ] registry add git@gitlab.sintef.no:clean_export/registrycleanexport.git
>     ```
>  3. Install the base package [`EnergyModelsBase.jl`](https://clean_export.pages.sintef.no/energymodelsbase.jl/) and the time package [`TimeStructures.jl`](https://clean_export.pages.sint    ef.no/timestructures.jl/), by running:
>     ```
>     ] add EnergyModelsBase
>     ] add TimeStructures
>     ```
>     This will fetch the packages from the CleanExport package registry.
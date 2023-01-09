# EnergyModelsBase

[![Pipeline: passing](https://gitlab.sintef.no/clean_export/energymodelsbase.jl/badges/main/pipeline.svg)](https://gitlab.sintef.no/clean_export/energymodelsbase.jl/-/jobs)
[![Docs: stable](https://img.shields.io/badge/docs-stable-4495d1.svg)](https://clean_export.pages.sintef.no/energymodelsbase.jl)
<!---
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
--->
EnergyModelsBase is the foundation package to build flexible multi-energy-carrier energy systems models. It is designed to model the basic operations of various generation, conversion and storage technologies. EnergyModelsBase is designed to enable optimization of operations, and to be be easily extendible to investment models, and/or to include new technologies or more detailed models of key technologies.

> **Note**
> This is an internal pre-release not intended for distribution outside the project consortium. 

## Usage

Documentation is in preparation. For a minimal example, do:

```julia
using EnergyModelsBase
using HiGHS
using JuMP
using PrettyTables
using TimeStructures

const EMB = EnergyModelsBase

function emb_demo()
    # Read test case from EnergyModelsBase
    m, case = EMB.run_model("", nothing, HiGHS.Optimizer)

    # Optimize
    set_optimizer(m, HiGHS.Optimizer)
    optimize!(m)

    # Inspect some of the results
    pretty_table(
        JuMP.Containers.rowtable(
            value,
            m[:flow_out];
            header = [:Node, :TimePeriod, :Resource, :FlowOut],
        ),
    )
end

emb_demo()
```


## Project Funding

EnergyModelsBase was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)
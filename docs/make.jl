using Documenter

using EnergyModelsBase
using TimeStruct
const EMB = EnergyModelsBase

# Copy the NEWS.md file
news = "docs/src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp("NEWS.md", news)


DocMeta.setdocmeta!(EnergyModelsBase, :DocTestSetup, :(using EnergyModelsBase); recursive=true)

makedocs(
    sitename = "EnergyModelsBase.jl",
    format = Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="main",
        assets=String[],
    ),
    modules = [EnergyModelsBase],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Philosophy" => "manual/philosophy.md",
            "Optimization variables" => "manual/optimization-variables.md",
            "Constraint functions" => "manual/constraint-functions.md",
            "Data functions" => "manual/data-functions.md",
            "Example" => "manual/simple-example.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "How-to" => Any[
            "Create a new node" => "how-to/create-new-node.md",
            "Utilize TimeStruct.jl" => "how-to/utilize-timestruct.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => Any[
                "Reference" => "library/internals/reference.md",
            ]
        ]
    ]
)

deploydocs(;
    push_preview = true,
    repo = "github.com/EnergyModelsX/EnergyModelsBase.jl.git",
)

using Documenter

using EnergyModelsBase
const EMB = EnergyModelsBase

# Copy the NEWS.md file
news = "src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp("../NEWS.md", "src/manual/NEWS.md")


DocMeta.setdocmeta!(EnergyModelsBase, :DocTestSetup, :(using EnergyModelsBase); recursive=true)

makedocs(
    sitename = "EnergyModelsBase.jl",
    repo="https://gitlab.sintef.no/clean_export/energymodelsbase.jl/blob/{commit}{path}#{line}",
    format = Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://clean_export.pages.sintef.no/energymodelsbase.jl/",
        edit_link="main",
        assets=String[],
    ),
    modules = [EnergyModelsBase],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Philosophy" => "manual/philosophy.md",
            "Nodes" => "manual/nodes.md",
            "Example" => "manual/simple-example.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "How-to" => Any[
            "Create a new node" => "how-to/create-new-node.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => Any[
                "Optimization variables" => "library/internals/optimization-variables.md",
                "Constraint functions" => "library/internals/constraint-functions.md",
                "Reference" => "library/internals/reference.md",
            ]
        ]
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#

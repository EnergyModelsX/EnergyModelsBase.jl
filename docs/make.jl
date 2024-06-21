using Documenter

using EnergyModelsBase
using EnergyModelsInvestments
using TimeStruct
const EMB = EnergyModelsBase

# Copy the NEWS.md file
news = "docs/src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp("NEWS.md", news)

DocMeta.setdocmeta!(
    EnergyModelsBase,
    :DocTestSetup,
    :(using EnergyModelsBase);
    recursive = true,
)

makedocs(
    sitename = "EnergyModelsBase",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = "main",
        assets = String[],
        ansicolor = true,
    ),
    modules = [
        EMB,
        isdefined(Base, :get_extension) ?
        Base.get_extension(EMB, :EMIExt) :
        EMB.EMIExt
        ],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start"=>"manual/quick-start.md",
            "Philosophy"=>"manual/philosophy.md",
            "Optimization variables"=>"manual/optimization-variables.md",
            "Constraint functions"=>"manual/constraint-functions.md",
            "Data functions"=>"manual/data-functions.md",
            "Example"=>"manual/simple-example.md",
            "Release notes"=>"manual/NEWS.md",
        ],
        "How to" => Any[
            "Create a new node"=>"how-to/create-new-node.md",
            "Utilize TimeStruct"=>"how-to/utilize-timestruct.md",
            "Update models"=>"how-to/update-models.md",
            "Contribute to EnergyModelsBase"=>"how-to/contribute.md",
        ],
        "Library" => Any[
            "Public"=>"library/public.md",
            "Internals"=>Any[
                "Reference"=>"library/internals/reference.md",
                "Reference EMIExt"=>"library/internals/reference_EMIExt.md",
            ],
        ],
    ],
)

deploydocs(;
    repo = "github.com/EnergyModelsX/EnergyModelsBase.jl.git",
)

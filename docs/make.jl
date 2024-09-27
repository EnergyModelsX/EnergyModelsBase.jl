using Documenter
using DocumenterInterLinks

using EnergyModelsBase
using EnergyModelsInvestments
using TimeStruct
const EMB = EnergyModelsBase

# Copy the NEWS.md file
cp("NEWS.md", "docs/src/manual/NEWS.md"; force=true)

links = InterLinks(
    "TimeStruct" => "https://sintefore.github.io/TimeStruct.jl/stable/",
    "EnergyModelsInvestments" => "https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/",
)


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
            "Investment options"=>"manual/investments.md",
            "Release notes"=>"manual/NEWS.md",
        ],
        "Nodes" => Any[
            "Source" => "nodes/source.md",
            "NetworkNode" => "nodes/networknode.md",
            "Storage" => "nodes/storage.md",
            "Sink" => "nodes/sink.md",
        ],
        "How to" => Any[
            "Create a new node"=>"how-to/create-new-node.md",
            "Utilize TimeStruct"=>"how-to/utilize-timestruct.md",
            "Update models"=>"how-to/update-models.md",
            "Contribute to EnergyModelsBase"=>"how-to/contribute.md",
        ],
        "Library" => Any[
            "Public" => Any[
                "Resources"=>"library/public/resources.md",
                "Modeltype and Data"=>"library/public/model_data.md",
                "Nodes"=>"library/public/nodes.md",
                "Links"=>"library/public/links.md",
                "Functions"=>"library/public/functions.md",
                "Miscellaneous"=>"library/public/misc.md",
                "EMI extension"=>"library/public/emi_extension.md",
            ],
            "Internal" => Any[
                "Reference"=>"library/internals/reference.md",
                "Reference EMIExt"=>"library/internals/reference_EMIExt.md",
            ],
        ],
    ],
    plugins=[links],
)

deploydocs(;
    repo = "github.com/EnergyModelsX/EnergyModelsBase.jl.git",
)

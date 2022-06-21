push!(LOAD_PATH,"../src/")

try
    using Documenter
catch
    import Pkg
    Pkg.activate(@__DIR__)
    Pkg.instantiate()
    
    using Documenter
end

using EnergyModelsBase
const EMB = EnergyModelsBase

makedocs(
    sitename = "EnergyModelsBase",
    format = Documenter.HTML(),
    modules = [EnergyModelsBase],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Philosophy" => "manual/philosophy.md",
            "Example" => "manual/simple-example.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => "library/internals.md"
        ]
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#

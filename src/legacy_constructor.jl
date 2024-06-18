"""
    RefStorage(
        id,
        rate_cap::TimeProfile,
        stor_cap::TimeProfile,
        opex_var::TimeProfile,
        opex_fixed::TimeProfile,
        stor_res::ResourceEmit,
        input::Dict{<:Resource,<:Real},
        output::Dict{<:Resource,<:Real},
        data::Vector,
    )

Legacy constructor for a `RefStorage{ResourceEmit}`.
This version will be discontinued in the near future and replaced with the new version of
`RefStorage{StorageBehavior}` in which the parametric input defines the behaviour of the
storage.

See the *[documentation](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/how-to/update-models)*
for further information regarding how you can translate your existing model to the new model.
"""
function RefStorage(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceEmit,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    data::Vector,
)

    @warn(
        "The used implementation of a `RefStorage` will be discontinued in the near future. " *
        "See the documentation for the new implementation using a parametric type describing " *
        "the storage behaviour and the changes incorporated for level and charge through using " *
        "the types `StorageBehavior` and `AbstractStorageParameters` in the section on " *
        "_How to update your model to the latest versions_.\n" *
        "In practice, two changes have to be incorporated: \n 1. `RefStorage{AccumulatingEmissions}()` " *
        "instead of `RefStorage` and \n 2. the application of `StorCapOpex(rate_cap, opex_var, opex_fixed)` " *
        "as 2ⁿᵈ field as well as `StorCap(stor_cap)` as 3ʳᵈ field instead of using " *
        "`rate_cap`, `stor_cap`, `opex_var`, and `opex_fixed` as 2ⁿᵈ-5ᵗʰ fields.\n" *
        "It is recommended to update the existing implementation to the new version.",
        maxlog = 1
    )

    tmp = RefStorage{AccumulatingEmissions}(
        id,
        StorCapOpex(rate_cap, opex_var, opex_fixed),
        StorCap(stor_cap),
        stor_res,
        input,
        output,
        data,
    )
    return tmp
end
function RefStorage(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceEmit,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
)

    @warn(
        "The used implementation of a `RefStorage` will be discontinued in the near future. " *
        "See the documentation for the new implementation using a parametric type describing " *
        "the storage behaviour and the changes incorporated for level and charge through using " *
        "the types `StorageBehavior` and `AbstractStorageParameters` in the scetion on " *
        "_How to update your model to the latest versions_.\n" *
        "In practice, two changes have to be incorporated: \n 1. `RefStorage{AccumulatingEmissions}()` " *
        "instead of `RefStorage` and \n 2. the application of `StorCapOpex(rate_cap, opex_var, opex_fixed)` " *
        "as 2ⁿᵈ field as well as `StorCap(stor_cap)` as 3ʳᵈ field instead of using " *
        "`rate_cap`, `stor_cap`, `opex_var`, and `opex_fixed` as 2ⁿᵈ-5ᵗʰ fields.\n" *
        "It is recommended to update the existing implementation to the new version.",
        maxlog = 1
    )

    tmp = RefStorage{AccumulatingEmissions}(
        id,
        StorCapOpex(rate_cap, opex_var, opex_fixed),
        StorCap(stor_cap),
        stor_res,
        input,
        output,
        Data[],
    )
    return tmp
end

"""
    RefStorage(
        id,
        rate_cap::TimeProfile,
        stor_cap::TimeProfile,
        opex_var::TimeProfile,
        opex_fixed::TimeProfile,
        stor_res::ResourceCarrier,
        input::Dict{<:Resource,<:Real},
        output::Dict{<:Resource,<:Real},
        data::Vector,
    )

Legacy constructor for a `RefStorage{ResourceCarrier}`.
This version will be discontinued in the near future and replaced with the new version of
`RefStorage{StorageBehavior}` in which the parametric input defines the behaviour of the
storage.

See the *[documentation](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/how-to/update-models)*
for further information regarding how you can translate your existing model to the new model.
"""
function RefStorage(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    data::Vector,
)

    @warn(
        "The used implementation of a `RefStorage` will be discontinued in the near future. " *
        "See the documentation for the new implementation using a parametric type describing " *
        "the storage behaviour and the changes incorporated for level and charge through using " *
        "the types `StorageBehavior` and `AbstractStorageParameters` in the scetion on " *
        "_How to update your model to the latest versions_.\n" *
        "In practice, two changes have to be incorporated: \n 1. `RefStorage{CyclicStrategic}()` " *
        "instead of `RefStorage` and \n 2. the application of `StorCapOpexVar(rate_cap, opex_var)` " *
        "as 2ⁿᵈ field as well as `StorCapOpexFixed(stor_cap, opex_fixed)` as 3ʳᵈ " *
        "field instead of using `rate_cap`, `stor_cap`, `opex_var`, and `opex_fixed` as " *
        "2ⁿᵈ-5ᵗʰ fields.\n" *
        "It is recommended to update the existing implementation to the new version.",
        maxlog = 1
    )

    tmp = RefStorage{CyclicStrategic}(
        id,
        StorCapOpexVar(rate_cap, opex_var),
        StorCapOpexFixed(stor_cap, opex_fixed),
        stor_res,
        input,
        output,
        data,
    )
    return tmp
end
function RefStorage(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
)

    @warn(
        "The used implementation of a `RefStorage` will be discontinued in the near future. " *
        "See the documentation for the new implementation using a parametric type describing " *
        "the storage behaviour and the changes incorporated for level and charge through using " *
        "the types `StorageBehavior` and `AbstractStorageParameters` in the scetion on " *
        "_How to update your model to the latest versions_.\n" *
        "In practice, two changes have to be incorporated: \n 1. `RefStorage{CyclicStrategic}()` " *
        "instead of `RefStorage` and \n 2. the application of `StorCapOpexVar(rate_cap, opex_var)` " *
        "as 2ⁿᵈ field as well as `StorCapOpexFixed(stor_cap, opex_fixed)` as 3ʳᵈ " *
        "field instead of using `rate_cap`, `stor_cap`, `opex_var`, and `opex_fixed` as " *
        "2ⁿᵈ-5ᵗʰ fields.\n" *
        "It is recommended to update the existing implementation to the new version.",
        maxlog = 1
    )

    tmp = RefStorage{CyclicStrategic}(
        id,
        StorCapOpexVar(rate_cap, opex_var),
        StorCapOpexFixed(stor_cap, opex_fixed),
        stor_res,
        input,
        output,
        Data[],
    )
    return tmp
end

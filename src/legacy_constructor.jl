"""
Legacy constructor for a `RefStorage{ResourceEmit}`.
This version will be discontinued in the near future and replaced with the new version of
`RefStorage{StorageBehavior}` in which the parametric input defines the behaviour of the
storage.

See the documentation for further information. In this case, the key difference is that we
changed the parameteric descriptions from the stored `Resource` to the behaviour of the
`Storage` node as well as allowing for variable and fixed OPEX for both the level and the
charge rate as well as allowing for the introduction of a discharge rate.
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

    @warn("The used implementation of a `RefStorage` will be discontinued in the near future. \
    See the documentation for the new implementation using a parametric type describing \
    the storage behaviour and the changes incorporated for level and charge through using \
    the type `AbstractStorageParameters`.\n\
    In practice, two changes have to be incorporated: \n 1. `RefStorage{AccumulatingEmissions}()` \
    instead of `RefStorage` and \n 2. the application of `StorCapOpex(rate_cap, opex_var, opex_fixed)` \
    as 2ⁿᵈ field as well as `StorCap(stor_cap)` as 3ʳᵈ field instead of using \
    `rate_cap`, `stor_cap`, `opex_var`, and `opex_fixed` as 2ⁿᵈ-5ᵗʰ fields.\n\
    It is recommended to update the existing implementation to the new version.")

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

    @warn("The used implementation of a `RefStorage` will be discontinued in the near future. \
    See the documentation for the new implementation using a parametric type describing \
    the storage behaviour and the changes incorporated for level and charge through using \
    the type `AbstractStorageParameters`.\n\
    In practice, two changes have to be incorporated: \n1. `RefStorage{AccumulatingEmissions}()` \
    instead of `RefStorage` and \n2. the application of `StorCapOpex(rate_cap, opex_var, opex_fixed)` \
    as 2ⁿᵈ field as well as `StorCap(stor_cap)` as 3ʳᵈ field instead of using \
    `rate_cap`, `stor_cap`, `opex_var`, and `opex_fixed` as 2ⁿᵈ-5ᵗʰ fields.\n\
    It is recommended to update the existing implementation to the new version.")

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
Legacy constructor for a `RefStorage{ResourceCarrier}`.
This version will be discontinued in the near future and replaced with the new version of
`RefStorage{StorageBehavior}` in which the parametric input defines the behaviour of the
storage.

See the documentation for further information. In this case, the key difference is that we
changed the parameteric descriptions from the stored `Resource` to the behaviour of the
`Storage` node as well as allowing for variable and fixed OPEX for both the level and the
charge rate as well as allowing for the introduction of a discharge rate.
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

    @warn("The used implementation of a `RefStorage` will be discontinued in the near future. \
    See the documentation for the new implementation using a parametric type describing \
    the storage behaviour and the changes incorporated for level and charge through using \
    the type `AbstractStorageParameters`.\n\
    In practice, two changes have to be incorporated: \n1. `RefStorage{CyclicStrategic}()` \
    instead of `RefStorage()` and \n2. the application of `StorCapOpexVar(rate_cap, opex_var)` \
    as 2ⁿᵈ field as well as `StorCapOpexFixed(stor_cap, opex_var, opex_fixed)` as 3ʳᵈ field \
    instead of using `rate_cap`, `stor_cap`, `opex_var`, and `opex_fixed` as 2ⁿᵈ-5ᵗʰ fields.\n\
    It is recommended to update the existing implementation to the new version.")

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

    @warn("The used implementation of a `RefStorage` will be discontinued in the near future. \
    See the documentation for the new implementation using a parametric type describing \
    the storage behaviour and the changes incorporated for level and charge through using \
    the type `AbstractStorageParameters`.\n\
    In practice, two changes have to be incorporated: \n1. `RefStorage{CyclicStrategic}()` \
    instead of `RefStorage()` and \n2. the application of `StorCapOpexVar(rate_cap, opex_var)` \
    as 2ⁿᵈ field as well as `StorCapOpexFixed(stor_cap, opex_var, opex_fixed)` as 3ʳᵈ field \
    instead of using `rate_cap`, `stor_cap`, `opex_var`, and `opex_fixed` as 2ⁿᵈ-5ᵗʰ fields.\n\
    It is recommended to update the existing implementation to the new version.")

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

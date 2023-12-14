"""
Legacy constructor for a `RefSource` node with emissions. This version will be discontinued
in the near future and replaced with the new implementation of `data`.

See the documentation for further information. In this case, the emission data can be
implemented by the new `EmissionsData` type `EmissionsProcess`
"""
function RefSource(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    output::Dict{<:Resource,<:Real},
    data::Array,
    emissions::Dict{<:ResourceEmit,<:Real},
    )

    @warn("This implementation of a `RefSource` will be discontinued in the near future. \
    See the documentation for the new implementation using the `data` field.
    It is recommended to update the existing version to the new version.")

    em_data = EmissionsProcess(emissions)
    append!(data, [em_data])

    return RefSource(id, cap, opex_var, opex_fixed, output, data)
end

"""
Legacy constructor for a `RefNetwork` node. This version will be discontinued
in the near future. its new name is given by RefNetworkNode.
"""
function RefNetwork(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    data::Array,
    )

    @warn("The implementation of a `RefNetwork` will be discontinued in \
    the near future. The name is replaced by RefNetworkNode, while the fields remain \
    unchanged. It is recommended to update the existing version to the new version.")

    return RefNetworkNode(id, cap, opex_var, opex_fixed, input, output, data)
end

"""
Legacy constructor for a `RefNetworkEmissions` node. This version will be discontinued
in the near future and replaced with the new implementation of `data` and the application
of `RefNetworkNode`.

See the documentation for further information. In this case, the emission data can be
implemented by the new `EmissionsData` type `CaptureEnergyEmissions`.
"""
function RefNetworkEmissions(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    emissions::Dict{<:ResourceEmit,<:Real},
    co2_capture::Real,
    data::Array,
    )

    @warn("The implementation of a `RefNetworkEmissions` will be discontinued in \
    the near future. See the documentation for the new implementation using the `data` \
    field. It is recommended to update the existing version to the new version.")

    em_data = CaptureEnergyEmissions(emissions, co2_capture)
    append!(data, [em_data])

    return RefNetworkNode(id, cap, opex_var, opex_fixed, input, output, data)
end

"""
Legacy constructor for a `RefStorageEmissions`. This version will be discontinued
in the near future and replaced with the new version of `RefStorage`.

See the documentation for further information. In this case, the key difference is that it
uses now a parametric type instead of a standard composite type to differentiate between
the storage of `ResourceCarrier` or `ResourceEmit`
"""
function RefStorageEmissions(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceEmit,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    data::Array,
    )

    @warn("The implementation of a `RefStorageEmissions` will be discontinued in \
    the near future. See the documentation for the new implementation using a parametric \
    type. In practice, the only thing changing is to use `RefStorage` instead of \
    `RefStorageEmissions`. It is recommended to update the existing version to the new \
    version.")

    tmp = RefStorage(
        id,
        rate_cap,
        stor_cap,
        opex_var,
        opex_fixed,
        stor_res,
        input,
        output,
        Array{Data}(data),
    )
    return tmp
end

"""
Legacy constructor for a `GenAvailability`. This version will be discontinued
in the near future and replaced with the new implementation of `data`.

See the documentation for further information.
"""
function GenAvailability(
    id,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    )

    @warn("This implementation of a `GenAvailability` will be discontinued in \
    the near future. See the documentation for the new implementation not requiring using \
    a dictionary. It is recommended to update the existing version to the new version.")

    return GenAvailability(id, collect(keys(input)), collect(keys(output)))
end

"""
Legacy constructor for a `RefSink` node with [process] emissions. This version will be
discontinued in the near future and replaced with the new implementation of `data`.

See the documentation for further information. In this case, the emission data can be
implemented by the new `EmissionsData` type `EmissionsProcess`
"""
function RefSink(
    id,
    cap::TimeProfile,
    penalty::Dict{<:Any,<:TimeProfile},
    input::Dict{<:Resource,<:Real},
    emissions::Dict{<:ResourceEmit,<:Real},
    )

    @warn("This implementation of a `RefSink` will be discontinued in the near future. \
    See the documentation for the new implementation using the `data` field. \
    It is recommended to update the existing version to the new version.")

    em_data = EmissionsProcess(emissions)

    return RefSink(id, cap, penalty, input, [em_data])
end


"""
Legacy constructor for an `OperationalModel` without emission prices. This version will be
discontinued in the near future and replaced with the new implementation with an emission
price.

See the documentation for further information regarding the introduction of an emission
price.
"""
function OperationalModel(
    emission_limit::Dict{<:ResourceEmit, <:TimeProfile},
    co2_instance::ResourceEmit,
    )

    @warn("this implementation of `OperationalModel` will be discontinued in the near \
    future. See the documentation for the new implementation with the additional field:
    `emission_price`")

    emission_price = Dict(k => FixedProfile(0) for k ∈ keys(emission_limit))

    return OperationalModel(emission_limit, emission_price, co2_instance)
end

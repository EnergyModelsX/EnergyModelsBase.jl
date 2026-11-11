"""
    check_link(l::Link, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_link(l::Direct, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the fields of a [`Link`](@ref) corresponds to required structure. The default
functionality does not check anthing, aside from the checks performed in [`check_elements`](@ref).

## Checks `Direct`
- The functions [`inputs`](@ref) and [`outputs`](@ref) must be non-empty.

!!! tip "Creating a new link type"
    When developing a new link with new checks, it is important to create a new method for
    `check_link`.
"""
check_link(l::Link, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) = nothing
function check_link(l::Direct, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

    @assert_or_log(
        !isempty(link_res(l)),
        "The functions `inputs` and `outputs` return an empty `Vector`. This implies that " *
        "the nodes in the fields `:from` and `:to` do not have common `Resources` as " *
        "`outputs` and `inputs`, respectively. Hence, the link will not be used."
    )
end

"""
    check_link_data(l::Link, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the included `ExtensionData` types of a `Link` correspond to required structure.
"""
check_link_data(l::Link, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) =
    nothing

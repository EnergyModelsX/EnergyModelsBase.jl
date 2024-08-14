# [Update your model to the latest versions](@id how_to-update)

`EnergyModelsBase` is still in a pre-release version.
Hence, there are frequently breaking changes occuring, although we plan to keep backwards compatibility.
This document is designed to provide users with information regarding how they have to adjust their models to keep compatibility to the latest changes.
We will as well implement information regarding the adjustment of extension packages, although this is more difficult due to the vast majority of potential changes.

## [Adjustments from 0.6.x](@id how_to-update-06)

### [Key changes for nodal descriptions](@id how_to-update-06-nodes)

Version 0.7 introduced both *[storage behaviours](@ref lib-pub-nodes-stor_behav)* resulting in a rework of the individual approach for calculating the level balance as well as the potential to have charge and discharge capacities through *[storage parameters](@ref lib-pub-nodes-stor_par)*.

!!! note
    The legacy constructors for calls of the composite type of version 0.6 will be included at least until version 0.8.

### [`RefStorage`](@ref)

`RefStorage` was significantly reworked since version 0.6.
The total rework is provided below.

If you are previously using the functions [`capacity`](@ref), [`opex_var`](@ref), and [`opex_fixed`](@ref) directly on the nodal type, you have to adjust as well your call of the function as they now require the call on the `StorageParameter` type.

#### `RefStorage{<:ResourceCarrier}` translates to `RefStorage{CyclicStrategic}`

```julia
# The previous nodal description for a storage node storing a `ResourceCarrier` was given by:
RefStorage(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    data::Array,
)

# This translates to the following new version
RefStorage{CyclicStrategic}(
    id,
    StorCapOpexVar(rate_cap, opex_var),
    StorCapOpexFixed(stor_cap, opex_fixed),
    stor_res,
    input,
    output,
    data,
)
```

#### `RefStorage{<:ResourceEmit}` translates to `RefStorage{AccumulatingEmissions}`

```julia
# The previous nodal description for a storage node storing a `ResourceEmit` was given by:
RefStorageEmissions(
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

# This translates to the following new version
RefStorage{AccumulatingEmissions}(
    id,
    StorCapOpex(rate_cap, opex_var, opex_fixed),
    StorCap(stor_cap),
    stor_res,
    input,
    output,
    data,
)
```

## [Adjustments from 0.5.x to 0.7.x](@id how_to-update-05)

### [Key changes for nodal descriptions](@id how_to-update-05-nodes)

Version 0.6 introduced [`EmissionsData`](@ref) for providing the user with more flexibility (and less input demand) for incorporating different types of emissions to the model. Hence, the `Node` types were adjusted.
In addition, version 0.6 simplified the [`GenAvailability`](@ref) node and added emissions prices to the [`OperationalModel`](@ref).

Version 0.7 introduced both *[storage behaviours](@ref lib-pub-nodes-stor_behav)* resulting in a rework of the individual approach for calculating the level balance as well as the potential to have charge and discharge capacities through *[storage parameters](@ref lib-pub-nodes-stor_par)*.

!!! warning
    The legacy constructors for calls of the composite type of version 0.5 were removed in version 0.7.
    In addition, the adjustments will not be updated in release 0.8 as the models will be at that time most likely more than 1 year old.

### [`RefSource`](@ref)

```julia
# The previous nodal description was given by:
RefSource(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    output::Dict{<:Resource,<:Real},
    data::Array,
    emissions::Dict{<:ResourceEmit,<:Real},
)

# This translates to the following new version
em_data = EmissionsProcess(emissions)
append!(data, [em_data])
RefSource(id, cap, opex_var, opex_fixed, output, data)
```

### `RefNetwork` and `RefNetworkEmissions` to [`RefNetworkNode`](@ref)

The introduction of [`EmissionsData`](@ref) allowed to condense both previous types into a single new type.
This new type was renamed to `RefNetworkNode`.

```julia
# The previous nodal description for a network node without emissions was given by:
RefNetwork(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    data::Array,
)

# This translates to the following new version
RefNetworkNode(id, cap, opex_var, opex_fixed, input, output, data)
```

```julia
# The previous nodal description for a network node without emissions was given by:
RefNetworkEmissions(
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

# This translates to the following new version
em_data = CaptureEnergyEmissions(emissions, co2_capture)
append!(data, [em_data])
RefNetworkNode(id, cap, opex_var, opex_fixed, input, output, data)
```

### [`RefStorage`](@ref)

`RefStorage` was significantly reworked since version 0.5.
The total rework is provided below.

If you are previously using the functions [`capacity`](@ref), [`opex_var`](@ref), and [`opex_fixed`](@ref) directly on the nodal type, you have to adjust as well your call of the function as they now require the call on the `StorageParameter` type.

#### `RefStorage` translated to `RefStorage{CyclicStrategic}`

```julia
# The previous nodal description for a storage node storing a `ResourceCarrier` was given by:
RefStorage(
    id,
    rate_cap::TimeProfile,
    stor_cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    stor_res::ResourceCarrier,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    data::Array,
)

# This translates to the following new version
RefStorage{CyclicStrategic}(
    id,
    StorCapOpexVar(rate_cap, opex_var),
    StorCapOpexFixed(stor_cap, opex_fixed),
    stor_res,
    input,
    output,
    data,
)
```

#### `RefStorageEmissions` translated to `RefStorage{AccumulatingEmissions}`

```julia
# The previous nodal description for a storage node storing a `ResourceEmit` was given by:
RefStorageEmissions(
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

# This translates to the following new version
RefStorage{AccumulatingEmissions}(
    id,
    StorCapOpex(rate_cap, opex_var, opex_fixed),
    StorCap(stor_cap),
    stor_res,
    input,
    output,
    data,
)
```

### [`RefSink`](@ref)

`RefSink` has now as well the potential for investments although this would require a new type as the current operational cost calculated would incentivize retiring the demand directly.

```julia
# The previous nodal description was given by:
RefSink(
    id,
    cap::TimeProfile,
    penalty::Dict{<:Any,<:TimeProfile},
    input::Dict{<:Resource,<:Real},
    emissions::Dict{<:ResourceEmit,<:Real},
)

# This translates to the following new version
em_data = EmissionsProcess(emissions)
RefSink(id, cap, penalty, input, [em_data])
```

### [`GenAvailability`](@ref)

`GenAvailability` nodes do not require any longer the data for `input` and `output`, as they utilize a constructor, if only a single array is given.

```julia
# The previous nodal description was given by:
GenAvailability(
    id,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
)

# This translates to the following new version
GenAvailability(id, collect(keys(input)), collect(keys(output)))
```

### [`OperationalModel`](@ref)

`OperationalModel` incorporated the concept of emission prices as initially introduced in `EnergyModelsInvestments`.

```julia
# The previous model description was given by:
OperationalModel(
    emission_limit::Dict{<:ResourceEmit, <:TimeProfile},
    co2_instance::ResourceEmit,
)

# This translates to the following new version
emission_price = Dict(k => FixedProfile(0) for k ∈ keys(emission_limit))
OperationalModel(emission_limit, emission_price, co2_instance)
```

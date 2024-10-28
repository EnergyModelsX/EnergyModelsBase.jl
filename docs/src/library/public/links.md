# [Links](@id lib-pub-links)

`Link`s are connecting the individual `Node`s for the exchange of energy/mass.
`Link`s are directional, that is transport of mass/energy is only allowed in a single direction.

## Index

```@index
Pages = ["links.md"]
```

## [`Link` types](@id lib-pub-links-types)

The following types for links are implemented in `EnergyModelsBase`.
The thought process is to dispatch on the [`EMB.Formulation`](@ref) of a link as additional option.
This is in the current stage not implemented.

```@docs
Link
Direct
Linear
```

## [Functions for accessing fields of `Link` types](@id lib-pub-links-fun_field)

The following functions are declared for accessing fields from a `Link` type.

!!! warning "New link types"
    If you want to introduce new `Link` types, it is important that the function `formulation` is either functional for your new types or you have to declare a corresponding function.
    The first approach can be achieved through using the same name for the respective fields.

```@docs
inputs(n::Link)
outputs(n::Link)
formulation
link_data
```

## [Functions for identifying `Link`s](@id lib-pub-links-fun_identify)

The following functions are declared for filtering on `Link` types.

```@docs
has_capacity(l::Link)
has_emissions(l::Link)
has_opex(l::Link)
is_unidirectional(l::Link)
```

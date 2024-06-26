# Nodes

```julia
julia> using EnergyModelsBase
julia> const EMB = EnergyModelsBase
julia> using AbstractTrees
julia> AbstractTrees.children(x::Type) = subtypes(x)

julia> print_tree(EMB.Node)
```

```
Node
├─ NetworkNode
│  ├─ Availability
│  │  └─ GenAvailability
│  ├─ RefNetworkNode
│  └─ Storage
│     └─ RefStorage{T} where T<:StorageBehavior
├─ Sink
│  └─ RefSink
└─ Source
   └─ RefSource
```

The leaf nodes of the above type hierarchy tree are `composite type`s, while the inner
vertices are `abstract type`s.
The individual nodes and their fields are explained in [the public library](@ref sec_lib_public).

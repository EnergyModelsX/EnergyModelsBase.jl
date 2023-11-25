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
│     ├─ RefStorage
├─ Sink
│  └─ RefSink
└─ Source
   └─ RefSource
```

The leaf nodes of the above type hierarchy tree are `struct`s, while the inner
vertices are `abstract type`s.
The individual nodes and their fields are explained in [the public library](@ref sec_lib_public).

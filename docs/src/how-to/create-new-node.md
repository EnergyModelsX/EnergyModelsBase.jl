# [Create a new node](@id how_to-create_node)

The energy system model is based on the *[JuMP](https://jump.dev/JuMP.jl/)* optimization framework, so some basic knowledge on this Julia package is needed to implement a new technology node.

> **To create a new technology node named `NewTechNode`, we need to**
>
> 1. Implement a new `struct` (composite type), that is a subtypes of `Node`, `Source`, `Sink`, etc.
>    Here, a central choice is to decide on [*what abstract node type to subtype to*](@ref how_to-create_node-subtype).
> 2. Optional: implement the method
>
>    ```julia
>    variables_node(m, 𝒩ˢᵘᵇ::Vector{<:NewTechNode}, 𝒯, modeltype::EnergyModel)
>    ```
>
>    Implement this method if you want to create additional optimization variables for the new node. See *[how to create JuMP variables](https://jump.dev/JuMP.jl/stable/manual/variables/)* in the JuMP documentation.
> 3. Implement the method
>
>    ```julia
>    create_node(m, n::NewTechNode, 𝒯, 𝒫, modeltype::EnergyModel)
>    ```
>
>    In this method the constraints for the new node are created. See *[how to create JuMP constraints](https://jump.dev/JuMP.jl/stable/manual/constraints/)* in the JuMP documentation.

While step 1 is always required, it is possible to omit step 2 if no new variables are required.
It is also possible to create unregistered variables for each instance of the node.
This is however only advised if you do not need to access the value of the variables after the optimization.

!!! danger "Variable names"
    By default, it is not possible to use the same variable name twice within JuMP.
    I found some weird behavior in which it is possible to register the same variable name with a different node set, but it should not be possible to count on it.
    If you require variables, it is crucial to check whether the variable names are already utilized by other nodes you are using!
    The individual variables are shown on the description of individual nodes.

    It is hence in general advisable to provide a specific name including the node type as prefix, *e.g.*, `node_test_flow_in if you want to create a variable for a `NodeTest`.

!!! warning "Field names"
    When creating a new node type, you are free to change the field names to whatever name you desire. However, if you change the  field names, there are several things to consider:

    1. Certain functions are used within the core structure of the code for accessing the fields. These functions can be found in the *[Public Interface](@ref lib-pub-nodes-fun_field)*.
    2. The function [`EMB.check_node`](@ref) conducts some checks on the individual node data. If the fields and structure from the reference nodes are not present, you also have to create a new function for your node.

## [Additional tips for creating new nodes](@id how_to-create_node-tips)

1. If the `NewNodeType` should be able to include investments, it is necessary to i) call the function [`constraints_capacity_installed`](@ref).
   and ii) have the field `data`.
   The function is used for dispatching on the constraints for investments while the field `data` is used for providing the `InvestmentData`.
2. Emissions can be included in any way.
   It is however beneficial to reutilize the [`EmissionsData`](@ref) type to improve usability with other packages.
   This requries again the inclusion of the field `data` in `NewNodeType`.
   It is possible to also create new subtypes for `EmissionsData` as well as dispatch on the function [`constraints_data(m, n::Node, 𝒯, 𝒫, modeltype, data::Data)`](@ref man-data_fun).
3. It is in a first stage not important to include functions for handling all possible `TimeStructure`s, that is, *e.g.*, `RepresentativePeriods`.
   Instead, and error can be provided if an unsupported `TimeStructure` is chosen.
4. The existing reference nodes and their respective *[constraint functions](@ref man-con)* can serve as idea generators.
5. It is possible to include constraints that are coupled to another `Node` by introduing a field with the `Node` as type in the `NewNodeType`, *e.g.*, a field `node::Storage` when you plan to include additional constraints including a `Storage` node.
6. `EnergyModelsBase` utilize functions for accessing the fields of the individual nodes.
   These functions can be found in *[Functions for accessing fields of `Node` types](@ref lib-pub-nodes-fun_field)*.
   In general, these functions dispatch on `abstract type`s.
7. It is beneficial to include the fields `input` and `output` for the `NewTechNode`.
   This is not strictly required, but otherwise one has to provide new methods for the functions [`inputs()`](@ref) and  [`outputs()`](@ref).

## [Advanced creation of new nodes](@id how_to-create_node-adv)

Step 3 in the procedure is not necessarily required.
It is also possible to use the available *[constraint functions](@ref man-con)* for the new node type.
In this case, we have to first obtain an overview over the constraint functions called in

```julia
create_node(m, n::ParentNode, 𝒯, 𝒫, modeltype::EnergyModel)
```

in which `ParentNode` corresponds to the `abstract type` that is used as parent for the new `NewTechNode`.
Subsequently, we can add a method to the existing *constraint function* which is called by the `ParentNode`.
This *constraint function* has to dispatch on the created `NewTechNode` type.

!!! warning
    It is in general advised to create a new function *`create_node(m, n::NewTechNode, 𝒯, 𝒫, modeltype::EnergyModel)`*.
    The advantage here is that the user requires less understanding of the individual constraint functions.
    This may lead to repetetive code, but is the safer choice.

## [What abstract node type should you subtype to?](@id how_to-create_node-subtype)

The choice of node supertype depends on what optimization variables you need for the constraints describing the functionality of the new node.

A new node is defined as a composite type (`struct`) and subtype of one of the standard node types,

- [`Source`](@ref)
- [`NetworkNode`](@ref)
- [`Sink`](@ref)

Furthermore, we have the types

- [`Availability`](@ref) `<: NetworkNode`
- [`Storage`](@ref) `<: NetworkNode`

which correspond to a routing node (`Availability`) and a storage node (`Storage`).

The overall structure of the individual nodes can be printed to the REPL using the following code:

```julia
julia> using EnergyModelsBase
julia> const EMB = EnergyModelsBase
julia> using AbstractTrees
julia> AbstractTrees.children(x::Type) = subtypes(x)

julia> print_tree(EMB.Node)
```

```REPL
Node
├─ NetworkNode
│  ├─ Availability
│  │  └─ GenAvailability
│  ├─ RefNetworkNode
│  └─ Storage
│     └─ RefStorage
├─ Sink
│  └─ RefSink
└─ Source
   └─ RefSource
```

The leaf nodes of the above type hierarchy tree are `composite type`s, while the inner vertices are `abstract type`s.
The chosen parent `type` of the `NewNodeType` node decides what optimization variables are created for use by default.
You can find the created default optimization variables in *[Optimization Variables](@ref man-opt_var)* and *[Node types and respective variables](@ref man-opt_var-node)*.
The main difference between the individual parent types is whether they have only an energy/mass output (`Source`), input and output (`NetworkNode`), or input (`Sink`).
A more detailed explanation of the different `abstract type`s can be found in *[Description of Technologies](@ref man-phil-nodes)*

## [Example](@id how_to-create_node-example)

As an example, you can check out how [`EnergyModelsRenewableProducers`](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/) introduces two new technology types, a `Source` and a `Storage`.

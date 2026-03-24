# [Extend resource functionality](@id how_to-extend-resource-functionality)

```@meta
CurrentModule = EMB
```

This guide shows how to extend resource functionality by adding a custom resource
type and connecting it to custom variables and constraints through
resource-dispatch functions. This is useful for modelling more complex
resource behavior that cannot be captured by the default resource types where the standard
behavior is built around energy or mass flow.

The pattern follows the same structure as the resource dispatch test in
`test/test_resource.jl`:

1. Define a resource subtype with extra parameters.
2. Optionally create a custom node subtype that uses the resource.
3. Add resource-specific variables with `variables_flow_resource`.
4. Add resource-specific constraints with `constraints_resource`.
5. Couple node and link resource variables with `constraints_couple_resource`.

The example in the test suite defines a `PotentialPower` resource that has a potential,
with upper and lower bounds, in addition to energy flow. The flow of this potential
in and out of junctions follow equality constraints, as opposed to the energy and mass flow
which follow sum constraints.

The notation below follows the same conventions as the implementation and tests:

- `𝒩` for nodes
- `ℒ` for links
- `𝒫` for resources
- `𝒯` for the time structure
- `ℒᶠʳᵒᵐ`, `ℒᵗᵒ` for outgoing and incoming links of a node
- `𝒫ᵒᵘᵗ`, `𝒫ⁱⁿ`, `𝒫ˡⁱⁿᵏ` for resource subsets on outputs, inputs, and links

## 1. Define a special resource

Create a subtype of [`Resource`](@ref) and keep `co2_int` as the second field for
consistency with existing resource structures.

```julia
struct PotentialPower <: Resource
    id::String
    co2_int::Float64
    potential_lower::Float64
    potential_upper::Float64
end

EMB.is_resource_emit(::PotentialPower) = false
lower_limit(p::PotentialPower) = p.potential_lower
upper_limit(p::PotentialPower) = p.potential_upper
```

## 2. Define a custom node (optional)

If your resource needs dedicated node behavior, create a custom node subtype.
If the node subtype is parametrized, it can handle different types of resources
in different ways without defining multiple node types. In the dispatch test,
the custom node is an intermediate `NetworkNode` with a potential loss, but
without a loss in energy flow.

```julia
struct PotentialLossNode{T<:PotentialPower} <: NetworkNode
    id::Any
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    resource::T
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    data::Vector{<:ExtensionData}
    loss_factor::Float64
end

function PotentialLossNode(
    id,
    cap::TimeProfile,
    opex_var::TimeProfile,
    opex_fixed::TimeProfile,
    resource::T,
    loss_factor::Float64,
) where {T<:PotentialPower}
    return PotentialLossNode{T}(
        id,
        cap,
        opex_var,
        opex_fixed,
        resource,
        Dict(resource => 1.0),
        Dict(resource => 1.0),
        ExtensionData[],
        loss_factor,
    )
end
```

## 3. Declare resource-specific variables

Use [`variables_flow_resource`](@ref) to create resource variables.

Important:
- Declare each variable name once.
- Filter `𝒩` and `ℒ` down to the subsets that actually use the special resource.
- Keep bounds in `constraints_resource` when they depend on dispatch logic.

```julia
function EMB.variables_flow_resource(
    m,
    𝒩::Vector{<:EMB.Node},
    𝒫::Vector{<:PotentialPower},
    𝒯,
    modeltype::EnergyModel,
)
    output_nodes = filter(n -> any(p ∈ 𝒫 for p ∈ outputs(n)), 𝒩)
    input_nodes = filter(n -> any(p ∈ 𝒫 for p ∈ inputs(n)), 𝒩)

    @variable(
        m, energy_potential_node_out[
            n ∈ output_nodes, t ∈ 𝒯, p ∈ 𝒫; p ∈ outputs(n)
        ]
    )

    @variable(
        m, energy_potential_node_in[
            n ∈ input_nodes, t ∈ 𝒯, p ∈ intersect(inputs(n), 𝒫)
        ]
    )
end

function EMB.variables_flow_resource(
    m,
    ℒ::Vector{<:Link},
    𝒫::Vector{<:PotentialPower},
    𝒯,
    modeltype::EnergyModel,
)
    ℒᵉᵖ = filter(l -> any(p ∈ 𝒫 for p ∈ EMB.link_res(l)), ℒ)
    @variable(m, energy_potential_link_in[ℒᵉᵖ, 𝒯, 𝒫])
    @variable(m, energy_potential_link_out[ℒᵉᵖ, 𝒯, 𝒫])
end
```

## 4. Add resource-specific constraints

Use [`constraints_resource`](@ref) for custom node or link behavior.

```julia
function EMB.constraints_resource(
    m,
    n::PotentialLossNode,
    𝒯,
    𝒫::Vector{<:PotentialPower},
    modeltype::EnergyModel,
)
    𝒫ᵒᵘᵗ = filter(p -> p ∈ 𝒫, outputs(n))
    𝒫ⁱⁿ = filter(p -> p ∈ 𝒫, inputs(n))

    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:energy_potential_node_out][n, t, p] ==
            n.loss_factor * m[:energy_potential_node_in][n, t, p]
    )

    # Bounds are added as constraints because they rely on `p`,
    # which is an index in `energy_potential` variables.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:energy_potential_node_out][n, t, p] >= lower_limit(p)
    )
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:energy_potential_node_out][n, t, p] <= upper_limit(p)
    )
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:energy_potential_node_in][n, t, p] >= lower_limit(p)
    )
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:energy_potential_node_in][n, t, p] <= upper_limit(p)
    )

end

function EMB.constraints_resource(
    m,
    n::EMB.Node,
    𝒯,
    𝒫::Vector{<:PotentialPower},
    modeltype::EnergyModel,
)
    𝒫ᵒᵘᵗ = filter(p -> p ∈ 𝒫, outputs(n))
    𝒫ⁱⁿ = filter(p -> p ∈ 𝒫, inputs(n))

    # Bounds are added as constraints because they rely on `p`,
    # which is an index in `energy_potential` variables.
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:energy_potential_node_out][n, t, p] >= lower_limit(p)
    )
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:energy_potential_node_out][n, t, p] <= upper_limit(p)
    )
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:energy_potential_node_in][n, t, p] >= lower_limit(p)
    )
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ],
        m[:energy_potential_node_in][n, t, p] <= upper_limit(p)
    )
end

function EMB.constraints_resource(
    m,
    l::Link,
    𝒯,
    𝒫::Vector{<:PotentialPower},
    modeltype::EnergyModel,
)
    𝒫ˡⁱⁿᵏ = filter(p -> p ∈ 𝒫, EMB.link_res(l))
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ˡⁱⁿᵏ],
        m[:energy_potential_link_in][l, t, p] ==
            m[:energy_potential_link_out][l, t, p]
    )
end
```

## 5. Couple node and link variables

Use [`constraints_couple_resource`](@ref) to connect node and link resource variables.

```julia
function EMB.constraints_couple_resource(
    m,
    𝒩::Vector{<:EMB.Node},
    ℒ::Vector{<:Link},
    𝒫::Vector{<:PotentialPower},
    𝒯,
    modeltype::EnergyModel,
)
    for n ∈ 𝒩
        ℒᶠʳᵒᵐ, ℒᵗᵒ = EMB.link_sub(ℒ, n)
        𝒫ᵒᵘᵗ = filter(p -> p ∈ 𝒫, outputs(n))
        𝒫ⁱⁿ = filter(p -> p ∈ 𝒫, inputs(n))

        @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ, l ∈ ℒᶠʳᵒᵐ],
            m[:energy_potential_node_out][n, t, p] ==
                m[:energy_potential_link_in][l, t, p]
        )

        @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ, l ∈ ℒᵗᵒ],
            m[:energy_potential_link_out][l, t, p] ==
                m[:energy_potential_node_in][n, t, p]
        )
    end
end
```


Power = ResourceCarrier("Power", 0.0)
Heat = ResourceCarrier("Heat", 0.0)
CO2 = ResourceEmit("CO2", 1.0)

𝒫 = [Power, Heat, CO2]

@testset "Resource - get resource types" begin
    # returns a Vector of DataTypes
    @test EMB.res_types(𝒫) isa Vector{DataType}

    # returns the correct number of unique resource types
    @test length(EMB.res_types(𝒫)) == 2
end

@testset "Resource - get resource vectors by type" begin
    # returns a Vector
    @test EMB.res_types_vec(𝒫) isa Vector{Vector}

    # returns the correct number of segments
    @test length(EMB.res_types_vec(𝒫)) == 2

    # the length of the first segment should be 2 (2 ResourceCarriers)
    @test length(EMB.res_types_vec(𝒫)[1]) == 2

    # the length of the second segment should be 1 (1 ResourceEmit)
    @test length(EMB.res_types_vec(𝒫)[2]) == 1

end

@testset "Resource - get resource vectors by type w/ empty input" begin

    # returns an empty vector when given an empty resource vector
    @test isempty(EMB.res_types_vec(Resource[]))
end

# Add a new resource type and check that it is correctly identified by res_types and res_types_vec
struct TestResource <: Resource
    id::String
    a::Float64
    b::Int64
end

# Add a new resource of type TestResource to the resource vector
𝒫 = vcat(𝒫, [TestResource("Test", 0.5, 1)])

@testset "Resource - get resource types w/ custom resource type" begin
    # returns a Vector of DataTypes (now including TestResource)
    @test EMB.res_types(𝒫) isa Vector{DataType}

    # returns the correct number of unique resource types (now 3)
    @test length(EMB.res_types(𝒫)) == 3

end

@testset "Resource - get resource vectors by type w/ custom resource type" begin
    # returns the correct number of segments (now 3)
    @test length(EMB.res_types_vec(𝒫)) == 3

    # the length of the first segment should be 2 (2 ResourceCarriers)
    @test length(EMB.res_types_vec(𝒫)[1]) == 2

    # the length of the second segment should be 1 (1 ResourceEmit)
    @test length(EMB.res_types_vec(𝒫)[2]) == 1

    # the length of the third segment should be 1 (1 TestResource)
    @test length(EMB.res_types_vec(𝒫)[3]) == 1
end


# Implement a custom resource type and check that it is correctly handled in the model via dispatch
@testset "Resource - energy potential via dispatch" begin


        struct PotentialPower <: Resource
            id::String
            co2_int::Float64
            potential_lower::Float64
            potential_upper::Float64
        end
        EMB.is_resource_emit(::PotentialPower) = false
        lower_limit(p::PotentialPower) = p.potential_lower
        upper_limit(p::PotentialPower) = p.potential_upper

        # A costum node type that represents a potential loss node
        # which has an input and output resource and a loss factor that determines how much of the input potential is lost in the node
        # but there is no loss in energy
        struct PotentialLossNode{T <: PotentialPower} <: NetworkNode
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
        )  where {T <: PotentialPower}
            return PotentialLossNode{T}(id, cap, opex_var, opex_fixed, resource, Dict(resource=>1.0), Dict(resource=>1.0), ExtensionData[], loss_factor)
        end


    function extension_resource_graph(loss_factor::Float64)
        
        pp = PotentialPower("PotentialPower", 0.0, 0.9, 1.1)
        source = RefSource(
            "pp_source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(pp => 1),
        )
        loss_node = PotentialLossNode(
            "pp_loss",
            FixedProfile(4),
            FixedProfile(0),
            FixedProfile(0),
            pp,
            loss_factor,
        )
        sink = RefSink(
            "pp_sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(pp => 1),
        )

        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat = 10)
        nodes = [source, loss_node, sink]
        links = [
            Direct("src-loss", source, loss_node, Linear())
            Direct("loss-snk", loss_node, sink, Linear())
        ]
        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Case(T, [pp, CO2], [nodes, links], [[get_nodes, get_links]])

        return case, modeltype
    end 

    # Delcare new variables for the potential power resource
    function EMB.variables_flow_resource(
        m, 𝒩::Vector{<:EMB.Node}, 𝒫::Vector{<:PotentialPower}, 𝒯, modeltype::EnergyModel
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
        m, ℒ::Vector{<:Link}, 𝒫::Vector{<:PotentialPower}, 𝒯, modeltype::EnergyModel
    )
        ℒᵉᵖ = filter(l -> any(p ∈ 𝒫 for p ∈ EMB.link_res(l)), ℒ)
        @variable(m, energy_potential_link_in[ℒᵉᵖ, 𝒯, 𝒫])
        @variable(m, energy_potential_link_out[ℒᵉᵖ, 𝒯, 𝒫])
    end

    # Declare new constraints for the potential power resource using the newly declared variables
    function EMB.constraints_resource(
        m, n::PotentialLossNode, 𝒯, 𝒫::Vector{<:PotentialPower}, modeltype::EnergyModel
    )
        𝒫ᵒᵘᵗ = filter(p -> p ∈ 𝒫, outputs(n))
        𝒫ⁱⁿ = filter(p -> p ∈ 𝒫, inputs(n))

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

        @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
            m[:energy_potential_node_out][n, t, p] == n.loss_factor * m[:energy_potential_node_in][n, t, p]
        )
    end

    function EMB.constraints_resource(
        m, n::EMB.Node, 𝒯, 𝒫::Vector{<:PotentialPower}, modeltype::EnergyModel
    )
        𝒫ᵒᵘᵗ = filter(p -> p ∈ 𝒫, outputs(n))
        𝒫ⁱⁿ = filter(p -> p ∈ 𝒫, inputs(n))

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
        m, l::Link, 𝒯, 𝒫::Vector{<:PotentialPower}, modeltype::EnergyModel
    )
        𝒫ˡⁱⁿᵏ = filter(p -> p ∈ 𝒫, EMB.link_res(l))
        @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ˡⁱⁿᵏ],
            m[:energy_potential_link_in][l, t, p] == m[:energy_potential_link_out][l, t, p]
        )
    end
    
    function EMB.constraints_couple_resource(
        m, 𝒩::Vector{<:EMB.Node}, ℒ::Vector{<:Link},
        𝒫::Vector{<:PotentialPower}, 𝒯, modeltype::EnergyModel
    )
        for n ∈ 𝒩
            ℒᶠʳᵒᵐ, ℒᵗᵒ = EMB.link_sub(ℒ, n)
            𝒫ᵒᵘᵗ = filter(p -> p ∈ 𝒫, outputs(n))
            𝒫ⁱⁿ = filter(p -> p ∈ 𝒫, inputs(n))

            @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ, l ∈ ℒᶠʳᵒᵐ],
                m[:energy_potential_node_out][n, t, p] == m[:energy_potential_link_in][l, t, p]
            )

            @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ, l ∈ ℒᵗᵒ],
                m[:energy_potential_link_out][l, t, p] == m[:energy_potential_node_in][n, t, p]
            )
        end
    end


    case, modeltype = extension_resource_graph(0.9)
    pp, co2 = get_products(case)
    source, loss_node, sink = get_nodes(case)

    m = run_model(case, modeltype, HiGHS.Optimizer)
    𝒯 = get_time_struct(case)
    ℒ = get_links(case)
    n_t = length(𝒯)

    @test haskey(m, :energy_potential_node_in)
    @test haskey(m, :energy_potential_node_out)
    @test haskey(m, :energy_potential_link_in)
    @test haskey(m, :energy_potential_link_out)

    @test length(m[:energy_potential_node_in]) == 2 * n_t
    @test length(m[:energy_potential_node_out]) == 2 * n_t
    @test length(m[:energy_potential_link_in]) == length(ℒ) * n_t
    @test length(m[:energy_potential_link_out]) == length(ℒ) * n_t

    @test all(value(m[:energy_potential_node_out][source, t, pp]) >= lower_limit(pp) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_out][source, t, pp]) <= upper_limit(pp) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_in][sink, t, pp]) >= lower_limit(pp) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_in][sink, t, pp]) <= upper_limit(pp) for t ∈ 𝒯)

    @test all(value(m[:energy_potential_node_out][source, t, pp]) ≈ value(m[:energy_potential_link_in][ℒ[1], t, pp]) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_link_out][ℒ[1], t, pp]) ≈ value(m[:energy_potential_node_in][loss_node, t, pp]) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_out][loss_node, t, pp]) ≈ loss_node.loss_factor * value(m[:energy_potential_node_in][loss_node, t, pp]) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_out][loss_node, t, pp]) ≈ value(m[:energy_potential_link_in][ℒ[2], t, pp]) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_link_out][ℒ[2], t, pp]) ≈ value(m[:energy_potential_node_in][sink, t, pp]) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_out][loss_node, t, pp]) < value(m[:energy_potential_node_in][loss_node, t, pp]) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_out][source, t, pp]) < value(m[:flow_out][source, t, pp]) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_in][sink, t, pp]) < value(m[:flow_in][sink, t, pp]) for t ∈ 𝒯)
end

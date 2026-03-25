@testset "Resource - utilities" begin
    # Declare the resources
    Power = ResourceCarrier("Power", 0.0)
    Heat = ResourceCarrier("Heat", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    𝒫 = [Power, Heat, CO2]
    @testset "General" begin
        # returns a Vector of DataTypes
        @test EMB.res_types(𝒫) isa Vector{DataType}

        # returns the correct number of unique resource types
        @test length(EMB.res_types(𝒫)) == 2

        # returns a Vector
        @test EMB.res_types_vec(𝒫) isa Vector{Vector}

        # returns the correct number of segments
        @test length(EMB.res_types_vec(𝒫)) == 2

        # the length of the first segment should be 2 (2 ResourceCarriers)
        @test length(EMB.res_types_vec(𝒫)[1]) == 2

        # the length of the second segment should be 1 (1 ResourceEmit)
        @test length(EMB.res_types_vec(𝒫)[2]) == 1

        # returns an empty vector when given an empty resource vector
        @test isempty(EMB.res_types_vec(Resource[]))
    end
    @testset "Resource with parameters" begin
        struct TestResource <: Resource
            id::String
            a::Float64
            b::Int64
        end

        # Add a new resource of type TestResource to the resource vector
        push!(𝒫, TestResource("Test", 0.5, 1))

        # returns a Vector of DataTypes (now including TestResource)
        @test isa(EMB.res_types(𝒫), Vector{DataType})

        # returns the correct number of unique resource types (now 3)
        @test length(EMB.res_types(𝒫)) == 3

        # returns the correct number of segments (now 3)
        @test length(EMB.res_types_vec(𝒫)) == 3

        # the length of the first segment should be 2 (2 ResourceCarriers)
        @test length(EMB.res_types_vec(𝒫)[1]) == 2

        # the length of the second segment should be 1 (1 ResourceEmit)
        @test length(EMB.res_types_vec(𝒫)[2]) == 1

        # the length of the third segment should be 1 (1 TestResource)
        @test length(EMB.res_types_vec(𝒫)[3]) == 1
    end
end

# Implement a custom resource type and check that it is correctly handled in the model via dispatch
@testset "Resource - implementation" begin
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
        # which has an input and output resource and a loss factor that determines how much
        # of the input potential is lost in the node but there is no loss in energy
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


    function res_test_case(loss_factor::Float64)
        pp = PotentialPower("PotentialPower", 0.0, 0.9, 1.1)
        CO2 = ResourceEmit("CO2", 1.0)
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

        𝒯 = TwoLevel(2, 2, SimpleTimes(5, 2); op_per_strat = 10)
        𝒩 = [source, loss_node, sink]
        ℒ = [
            Direct("src-loss", source, loss_node, Linear())
            Direct("loss-snk", loss_node, sink, Linear())
        ]
        modeltype = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Case(𝒯, [pp, CO2], [𝒩, ℒ])

        return case, modeltype
    end

    # Delcare new variables for the potential power resource
    function EMB.variables_flow_resource(
        m, 𝒩::Vector{<:EMB.Node}, 𝒫::Vector{<:PotentialPower}, 𝒯, modeltype::EnergyModel
    )
        𝒩ᵒᵘᵗ = filter(n -> any(p ∈ 𝒫 for p ∈ outputs(n)), 𝒩)
        𝒩ⁱⁿ = filter(n -> any(p ∈ 𝒫 for p ∈ inputs(n)), 𝒩)

        @variable(m,
            lower_limit(p) ≤
                energy_potential_node_out[n ∈ 𝒩ᵒᵘᵗ, 𝒯, p ∈ intersect(outputs(n), 𝒫)] ≤
            upper_limit(p)
        )
        @variable(m,
            lower_limit(p) ≤
                energy_potential_node_in[n ∈ 𝒩ⁱⁿ, 𝒯, p ∈ intersect(inputs(n), 𝒫)] ≤
            upper_limit(p)
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

        @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
            m[:energy_potential_node_out][n, t, p] == n.loss_factor * m[:energy_potential_node_in][n, t, p]
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


    case, modeltype = res_test_case(0.9)
    pp, co2 = get_products(case)
    source, loss_node, sink = get_nodes(case)

    m = run_model(case, modeltype, HiGHS.Optimizer)
    𝒯 = get_time_struct(case)
    ℒ = get_links(case)
    n_t = length(𝒯)

    # Variable testing (calling of the correct function)
    # - variables_flow(m, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    # - variables_flow(m, ℒ::Vector{<:Link}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    # Check that the variables are created
    @test haskey(m, :energy_potential_node_in)
    @test haskey(m, :energy_potential_node_out)
    @test haskey(m, :energy_potential_link_in)
    @test haskey(m, :energy_potential_link_out)

    ## Check that the variables have the correct length
    @test length(m[:energy_potential_node_in]) == 2 * n_t
    @test length(m[:energy_potential_node_out]) == 2 * n_t
    @test length(m[:energy_potential_link_in]) == length(ℒ) * n_t
    @test length(m[:energy_potential_link_out]) == length(ℒ) * n_t

    ## Check that the bounds of the variables are enforced
    @test all(value(m[:energy_potential_node_out][source, t, pp]) ≥ lower_limit(pp) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_out][source, t, pp]) ≤ upper_limit(pp) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_in][sink, t, pp]) ≥ lower_limit(pp) for t ∈ 𝒯)
    @test all(value(m[:energy_potential_node_in][sink, t, pp]) ≤ upper_limit(pp) for t ∈ 𝒯)

    # Test that the coupling constraints are correctly enforced
    # - EMB.constraints_couple_resource
    @test all(
        value(m[:energy_potential_node_out][source, t, pp]) ≈
            value(m[:energy_potential_link_in][ℒ[1], t, pp])
    for t ∈ 𝒯)
    @test all(
        value(m[:energy_potential_link_out][ℒ[1], t, pp]) ≈
            value(m[:energy_potential_node_in][loss_node, t, pp])
    for t ∈ 𝒯)
    @test all(
        value(m[:energy_potential_node_out][loss_node, t, pp]) ≈
            loss_node.loss_factor * value(m[:energy_potential_node_in][loss_node, t, pp])
    for t ∈ 𝒯)
    @test all(
        value(m[:energy_potential_node_out][loss_node, t, pp]) ≈
            value(m[:energy_potential_link_in][ℒ[2], t, pp])
    for t ∈ 𝒯)
    @test all(
        value(m[:energy_potential_link_out][ℒ[2], t, pp]) ≈
            value(m[:energy_potential_node_in][sink, t, pp])
    for t ∈ 𝒯)
    @test all(
        value(m[:energy_potential_node_out][loss_node, t, pp]) <
            value(m[:energy_potential_node_in][loss_node, t, pp])
    for t ∈ 𝒯)
    @test all(
        value(m[:energy_potential_node_out][source, t, pp]) <
            value(m[:flow_out][source, t, pp])
    for t ∈ 𝒯)
    @test all(
        value(m[:energy_potential_node_in][sink, t, pp]) <
            value(m[:flow_in][sink, t, pp])
    for t ∈ 𝒯)
end

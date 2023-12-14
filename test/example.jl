include("example_model.jl")

@testset "Example model" begin
    case, model = generate_data()
    m = run_model(case, model, HiGHS.Optimizer)

    # Retrieve data from the case structure
    𝒫   = case[:products]
    NG  = 𝒫[1]
    CO2 = 𝒫[4]

    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    𝒩    = case[:nodes]
    𝒩ⁿᵒᵗ = EMB.nodes_not_av(𝒩)
    𝒩ᵉᵐ  = nodes_emissions(𝒩)
    avail    = 𝒩[1]
    NG_PP    = 𝒩[4]
    Coal_PP  = 𝒩[5]
    CO2_stor = 𝒩[6]
    demand   = 𝒩[7]

    ℒ    = case[:links]

    @testset "General tests" begin
        # Check for the objective value
        # (-1500 compared to 0.5.x to include fixed OPEX)
        @test objective_value(m) ≈ -44491.693

        # Check for the total number of variables
        # (-128 compared to 0.5.x as only defined for technologies with EmissionData)
        # (+ 16 compared to 0.5.x as increase in storage variables)
        @test size(all_variables(m))[1] == 1112

        # Check that total emissions of both methane and CO2 are within the constraint
        # - constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test sum(value.(m[:emissions_strategic])[t_inv, CO2]
                <=
                EMB.emission_limit(model, CO2, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:emissions_strategic])[t_inv, NG]
                <=
                EMB.emission_limit(model, NG, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)


        # Check that the total and strategic emissions are correctly calculated
        # - constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test sum(value.(m[:emissions_strategic][t_inv, CO2]) ≈
                sum(value.(m[:emissions_total][t, CO2]) * EMB.multiple(t_inv, t)
                for t ∈ t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) ≈
                    length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:emissions_total][t, CO2]) ≈
                sum(value.(m[:emissions_node][n, t, CO2]) for n ∈ 𝒩ᵉᵐ)
                for t ∈ 𝒯, atol=TEST_ATOL) ≈
                    length(𝒯)

        # Check that the objective value is properly calculated
        # - objective(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
        @test -sum((value.(m[:opex_var][n, t_inv]) + value.(m[:opex_fixed][n, t_inv])) *
                duration(t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ⁿᵒᵗ) ≈
                    objective_value(m) atol=TEST_ATOL

        # Check that the inlet and outlet flowrates in the links are correctly calculated
        # based on the inlet and outlet flowrats of the nodes
        # - constraints_node(m, 𝒩, 𝒯, 𝒫, ℒ, modeltype::EnergyModel)
        for n ∈ 𝒩
            ℒᶠʳᵒᵐ, ℒᵗᵒ = EMB.link_sub(ℒ, n)
            # Constraint for output flowrate and input links.
            if has_output(n)
                @test sum(value.(m[:flow_out][n, t, p]) ≈
                    sum(value.(m[:link_in][l, t, p]) for l in ℒᶠʳᵒᵐ if p ∈ inputs(l.to))
                    for t ∈ 𝒯, p ∈ outputs(n), atol=TEST_ATOL) ≈
                        length(𝒯) * length(outputs(n))
            end
            # Constraint for input flowrate and output links.
            if has_input(n)
                @test sum(value.(m[:flow_in][n, t, p]) ≈
                    sum(value.(m[:link_out][l, t, p]) for l in ℒᵗᵒ if p ∈ outputs(l.from))
                    for t ∈ 𝒯, p ∈ inputs(n), atol=TEST_ATOL) ≈
                        length(𝒯) * length(inputs(n))
            end
        end

        # Check that the total energy balances are fulfilled in the availability node for
        # each resource
        # - create_node(m, n::Availability, 𝒯, 𝒫, modeltype::EnergyModel)
        @test sum(value.(m[:flow_in][avail, t, p]) ≈
                value.(m[:flow_out][avail, t, p]) for t ∈ 𝒯, p ∈ 𝒫, atol=TEST_ATOL) ≈
                    length(𝒯) * length(𝒫)

        # Check that the link balance is correct
        # - create_link(m, 𝒯, 𝒫, l, formulation::Formulation)
        @test sum(sum(value.(m[:link_out][l, t, p]) ≈
                value.(m[:link_in][l, t, p])
                for t ∈ 𝒯, p ∈ EMB.link_res(l), atol=TEST_ATOL) ≈
                    length(𝒯) * length(EMB.link_res(l)) for l ∈ ℒ, atol=TEST_ATOL) ≈
                        length(ℒ)
    end
end

include("example_model.jl")

@testset "User interface" begin
    case, model = generate_data()
    m = run_model(case, model, HiGHS.Optimizer)

    # Retrieve data from the case structure
    𝒫   = case[:products]
    NG  = 𝒫[1]
    CO2 = 𝒫[4]

    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    nodes    = case[:nodes]
    avail    = nodes[1]
    NG_PP    = nodes[4]
    Coal_PP  = nodes[5]
    CO2_stor = nodes[6]
    demand   = nodes[7]

    @testset "General tests" begin
        # Check for the objective value
        @test objective_value(m) ≈ -42991.693

        # Check for the total number of variables
        @test size(all_variables(m))[1] == 1192

        # Check that total emissions of both methane and CO2 are within the constraint
        @test sum(value.(m[:emissions_strategic])[t_inv, CO2]
                <=
                EMB.emission_limit(model, CO2, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:emissions_strategic])[t_inv, NG]
                <=
                EMB.emission_limit(model, NG, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end

    @testset "Node tests" begin
        # Check that the total energy balances are fulfilled in the availability node for each resource
        @test sum(sum(value.(m[:flow_in])[avail, t, p] ==
                value.(m[:flow_out])[avail, t, p] for t ∈ 𝒯) for p ∈ 𝒫) ≈
                    length(𝒯) * length(𝒫)

        # Check that the input conversion is correct in both power plants
        @test sum(sum(value.(m[:cap_use])[NG_PP, t] * EMB.input(NG_PP, p) ≈
                value.(m[:flow_in])[NG_PP, t, p] for t ∈ 𝒯) for p ∈ EMB.input(NG_PP)) ==
                    length(𝒯) * length(EMB.input(NG_PP))
        @test sum(sum(value.(m[:cap_use])[Coal_PP, t] * EMB.input(Coal_PP, p) ≈
                value.(m[:flow_in])[Coal_PP, t, p] for t ∈ 𝒯) for p ∈ EMB.input(Coal_PP)) ==
                    length(𝒯) * length(EMB.input(Coal_PP))

        # Check that the CO2 capture rate is correct in the natural gas power plant
        @test sum(NG_PP.co2_capture * sum(EMB.co2_int(p_in) * value.(m[:flow_in])[NG_PP, t, p_in] for p_in ∈ EMB.input(NG_PP)) ≈
                value.(m[:flow_out])[NG_PP, t, CO2] for t ∈ 𝒯) ==
                    length(𝒯)

        # Check that the additional energy requirement in the storage is correct
        p_stor = EMB.storage_resource(CO2_stor)
        𝒫ᵃᵈᵈ  = setdiff(EMB.input(CO2_stor), [p_stor])
        @test sum(sum(value.(m[:flow_in])[CO2_stor, t, p_stor] * EMB.input(CO2_stor, p) ≈
                value.(m[:flow_in])[CO2_stor, t, p] for t ∈ 𝒯) for p ∈ 𝒫ᵃᵈᵈ) ==
                    length(𝒯) * length(𝒫ᵃᵈᵈ)

    end

end

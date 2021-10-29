function run_model(fn, optimizer=nothing)
   @debug "Run model" fn optimizer

    case = read_data(fn)
    model = OperationalModel()
    m = create_model(case, model)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @info "No optimizer given"
    end
    return m, case
end

struct data_test <: Data end

function read_data(fn)
    @debug "Read case data"
    @info "Hard coded dummy model for now"

    # Define the different resources
    NG       = ResourceEmit("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0.)
    CO2      = ResourceEmit("CO2",1.)
    products = [NG, Coal, Power, CO2]
    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k  => 0 for k ∈ products)
    # Creation of a dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0
    nodes = [
            GenAvailability(1, 𝒫₀, 𝒫₀),
            RefSource(2,        FixedProfile(1e12), FixedProfile(30),
                                FixedProfile(0), Dict(NG => 1), 𝒫ᵉᵐ₀,
                                Dict("InvestmentModels" => data_test())),  
            RefSource(3,        FixedProfile(1e12), FixedProfile(9),
                                FixedProfile(0), Dict(Coal => 1), 𝒫ᵉᵐ₀,
                                Dict("InvestmentModels" => data_test())),  
            RefGeneration(4,    FixedProfile(25),   FixedProfile(5.5),
                                FixedProfile(0), Dict(NG => 2),
                                Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0.9,
                                Dict("InvestmentModels" => data_test())),  
            RefGeneration(5,    FixedProfile(25),   FixedProfile(6),
                                FixedProfile(0),  Dict(Coal => 2.5),
                                Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,
                                Dict("InvestmentModels" => data_test())),  
            RefStorage(6,       FixedProfile(60),   FixedProfile(600), FixedProfile(9.1),
                                FixedProfile(0),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),
                                Dict("InvestmentModels" => data_test())),
            RefSink(7,          DynamicProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                                20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                                20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                                20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),
                                Dict(:Surplus => 0, :Deficit => 1e6),
                                Dict(Power => 1), 𝒫ᵉᵐ₀),
            ]
    links = [
            Direct(14,nodes[1],nodes[4],Linear())
            Direct(15,nodes[1],nodes[5],Linear())
            Direct(16,nodes[1],nodes[6],Linear())
            Direct(17,nodes[1],nodes[7],Linear())
            Direct(21,nodes[2],nodes[1],Linear())
            Direct(31,nodes[3],nodes[1],Linear())
            Direct(41,nodes[4],nodes[1],Linear())
            Direct(51,nodes[5],nodes[1],Linear())
            Direct(61,nodes[6],nodes[1],Linear())
            ]

    # Creation of the time structure and global data
    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    global_data = GlobalData(Dict(CO2 => StrategicFixedProfile([450, 400, 350, 300]),
                                  NG  => FixedProfile(1e6))
                                  )

    # WIP data structure
    case = Dict(
                :nodes          => nodes,
                :links          => links,
                :products       => products,
                :T              => T,
                :global_data    => global_data,
                )
    return case
end
function run_model(fn, optimizer=nothing)
   @debug "Run model" fn optimizer

    data = read_data(fn)
    case = OperationalCase(StrategicFixedProfile([450, 400, 350, 300]))
    model = OperationalModel(case)
    m = create_model(data, model)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @info "No optimizer given"
    end
    return m, data
end

function read_data(fn)
    @debug "Read data"
    @info "Hard coded dummy model for now"

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
            Availability(1, 𝒫₀, 𝒫₀),
            RefSource(2, FixedProfile(1e12), FixedProfile(30), Dict(NG => 1), 𝒫ᵉᵐ₀),  
            RefSource(3, FixedProfile(1e12), FixedProfile(9), Dict(Coal => 1), 𝒫ᵉᵐ₀),  
            RefGeneration(4, FixedProfile(25), FixedProfile(5.5), Dict(NG => 2), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0.9),  
            RefGeneration(5, FixedProfile(25), FixedProfile(6),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0),  
            RefStorage(6, FixedProfile(20), 600, FixedProfile(9.1),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1)),
            RefSink(7, DynamicProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),
                    Dict(:surplus => 0, :deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀),
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

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    # WIP data structure
    data = Dict(
                :nodes => nodes,
                :links => links,
                :products => products,
                :T => T,
                )
    return data
end
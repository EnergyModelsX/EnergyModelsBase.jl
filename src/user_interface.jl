function run_model(fn, optimizer=nothing)
   @debug "Run model" fn optimizer

    data = read_data(fn)
    m = create_model(data)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @info "No optimizer given"
    end
    return m
end

function read_data(fn)
    @debug "Read data"
    @info "Hard coded dummy model for now"

    NG       = ResourceCarrier("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0)
    CO2      = ResourceEmit("CO2",1)
    products = [NG, Coal, Power, CO2]
    nodes = [
            Availability(1),
            RefSource(2, FixedProfile(1e12), FixedProfile(30), Dict(NG => 1, Coal => 0, Power => 0, CO2 => 0)),  
            RefSource(3, FixedProfile(1e12), FixedProfile(9), Dict(NG => 0, Coal => 1, Power => 0, CO2 => 0)),  
            RefGeneration(4, FixedProfile(25), FixedProfile(5.5), Dict(NG => -2, Coal => 0, Power => 1, CO2 => 0), 0.9),  
            RefGeneration(5, FixedProfile(25), FixedProfile(6), Dict(NG => 0, Coal => -2.5, Power => 1, CO2 => 0), 0),  
            RefStorage(6, FixedProfile(100), FixedProfile(9.1), CO2, Dict(NG => 0, Coal => 0, Power => -0.02)),
            RefSink(7, DynamicProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),Dict(:surplus => 0, :deficit => 1e6),
                    Dict(NG => 0, Coal => 0, Power => -1, CO2 => 0)),
            ]
    links = [
            Direct(nodes[1],nodes[4],Linear())
            Direct(nodes[1],nodes[5],Linear())
            Direct(nodes[1],nodes[6],Linear())
            Direct(nodes[1],nodes[7],Linear())
            Direct(nodes[2],nodes[1],Linear())
            Direct(nodes[3],nodes[1],Linear())
            Direct(nodes[4],nodes[1],Linear())
            Direct(nodes[5],nodes[1],Linear())
            Direct(nodes[6],nodes[1],Linear())
            ]
    T = UniformTwoLevel(1, 1, 1, UniformTimes(1, 24, 1))
    # WIP data structure
    data = Dict(
                :nodes => nodes,
                :links => links,
                :products => products,
                :T => T,
                )
    return data
end
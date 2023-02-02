function run_model(fn, case = nothing, model = nothing, optimizer = nothing)
   @debug "Run model" fn optimizer

   if isnothing(case)
        case, model = read_data(fn)
   end

   m = create_model(case, model)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        set_optimizer_attribute(m, MOI.Silent(), true)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @info "No optimizer given"
    end
    return m, case, model
end

function read_data(fn)
    @debug "Read case data"
    @info "Hard coded dummy model for now"

    # Define the different resources
    NG       = ResourceEmit("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0.)
    CO2      = ResourceEmit("CO2",1.)
    products = [NG, Coal, Power, CO2]
    
    # Creation of a dictionary with entries of 0 for all resources for the availability node
    # to be able to create the links for the availability node.
    𝒫₀ = Dict(k  => 0 for k ∈ products)

    # Creation of a dictionary with entries of 0 for all emission resources
    # This dictionary is normally used as usage based non-energy emissions.
    𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO2 storage.
    nodes = [
            GenAvailability(1, 𝒫₀, 𝒫₀),
            RefSource(2,        FixedProfile(1e12), FixedProfile(30),
                                FixedProfile(0), Dict(NG => 1),
                                Dict("" => EmptyData())),  
            RefSource(3,        FixedProfile(1e12), FixedProfile(9),
                                FixedProfile(0), Dict(Coal => 1),
                                Dict("" => EmptyData())),  
            RefNetworkEmissions(4, FixedProfile(25),   FixedProfile(5.5),
                                FixedProfile(0), Dict(NG => 2),
                                Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0.9,
                                Dict("" => EmptyData())),  
            RefNetwork(5,       FixedProfile(25),   FixedProfile(6),
                                FixedProfile(0),  Dict(Coal => 2.5),
                                Dict(Power => 1),
                                Dict("" => EmptyData())),  
            RefStorageEmissions(6, FixedProfile(60),   FixedProfile(600), FixedProfile(9.1),
                                FixedProfile(0), CO2, Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),
                                Dict("" => EmptyData())),
            RefSink(7,          OperationalFixedProfile([20 30 40 30]),
                                Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
                                Dict(Power => 1)),
            ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
            Direct(14, nodes[1], nodes[4], Linear())
            Direct(15, nodes[1], nodes[5], Linear())
            Direct(16, nodes[1], nodes[6], Linear())
            Direct(17, nodes[1], nodes[7], Linear())
            Direct(21, nodes[2], nodes[1], Linear())
            Direct(31, nodes[3], nodes[1], Linear())
            Direct(41, nodes[4], nodes[1], Linear())
            Direct(51, nodes[5], nodes[1], Linear())
            Direct(61, nodes[6], nodes[1], Linear())
            ]

    # Creation of the time structure and global data
    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 4, 2))
    model = OperationalModel(
                            Dict(
                                CO2 => StrategicFixedProfile([160, 140, 120, 100]),
                                NG  => FixedProfile(1e6)
                            ),
                            CO2,
    )

    # WIP data structure
    case = Dict(
                :nodes          => nodes,
                :links          => links,
                :products       => products,
                :T              => T,
                )
    return case, model
end
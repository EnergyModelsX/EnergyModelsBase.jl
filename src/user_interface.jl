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
    return 0
end

function read_data(fn)
    @debug "Read data"
    @info "Hard coded dummy model for now"

    # WIP data structure
    data = Dict(
        :nodes => [
            Battery(1, FixedProfile(1), Dict()),
            GasTank(2, FixedProfile(π), Dict()),
        ],
        :links => [(1,2)],
        :products => [:NG, :H2, :CO2, :Power],
        :T => UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1)),
    )
    return data
end
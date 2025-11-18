@testset "Run examples" begin
    # Get the global logger and set the loglevel to Warn
    logger_org = global_logger()
    logger_new = ConsoleLogger(Warn)
    global_logger(logger_new)

    # Iterate through all examples and test the examples
    exdir = joinpath(@__DIR__, "../examples")
    files = filter(endswith(".jl"), readdir(exdir))
    for file ∈ files
        @testset "Example $file" begin
            redirect_stdio(stdout = devnull) do
                include(joinpath(exdir, file))
            end
            @test termination_status(m) == MOI.OPTIMAL
        end
    end
    Pkg.activate(@__DIR__)

    # Reset the loglevel
    global_logger(logger_org)
end

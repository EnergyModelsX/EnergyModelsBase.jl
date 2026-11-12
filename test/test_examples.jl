@testset "Run examples" begin
    # Run the examples in a separate process using the environment of the examples folder
    exdir = joinpath(@__DIR__, "..", "examples")
    cmd = addenv(
        `$(Base.julia_cmd()) --project=$exdir $(joinpath(@__DIR__, "run_examples.jl"))`,
        "EMX_TEST" => "true",
        "JULIA_LOAD_PATH" => join(["@", "@stdlib"], Sys.iswindows() ? ";" : ":"),
    )
    log_file = joinpath(mktempdir(), "run_examples.log")
    passed = open(log_file, "w") do io
        success(pipeline(cmd; stdout = io, stderr = io))
    end

    # Print the output of the examples if they failed
    passed || print(stderr, read(log_file, String))
    @test passed
end

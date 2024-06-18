@testset "Run examples" begin
    exdir = joinpath(@__DIR__, "../examples")
    files = filter(endswith(".jl"), readdir(exdir))
    for file in files
        @testset "Example $file" begin
            redirect_stdio(stdout=devnull) do
                include(joinpath(exdir, file))
            end
            @test termination_status(m) == MOI.OPTIMAL
        end
    end
    Pkg.activate(@__DIR__)
end

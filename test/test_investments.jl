using EnergyModelsInvestments

@testset "Simple network" begin
    # Create simple model
    function investment_model()
        # Define the different resources
        NG = ResourceEmit("NG", 0.2)
        Coal = ResourceCarrier("Coal", 0.35)
        Power = ResourceCarrier("Power", 0.0)
        CO2 = ResourceEmit("CO2", 1.0)
        products = [NG, Coal, Power, CO2]

        op_profile = OperationalProfile([
            20,
            20,
            20,
            20,
            25,
            30,
            35,
            35,
            40,
            40,
            40,
            40,
            40,
            35,
            35,
            30,
            25,
            30,
            35,
            30,
            25,
            20,
            20,
            20,
        ])

        nodes = [
            GenAvailability(1, products),
            RefSink(
                2,
                op_profile,
                Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
                Dict(Power => 1),
            ),
            RefSource(
                3,
                FixedProfile(30),
                FixedProfile(30),
                FixedProfile(100),
                Dict(NG => 1),
                [
                    SingleInvData(
                        FixedProfile(1000), # capex [€/kW]
                        FixedProfile(200),  # max installed capacity [kW]
                        FixedProfile(15),   # initial capacity [kW]
                        ContinuousInvestment(FixedProfile(10), FixedProfile(200)), # investment mode
                    ),
                ],
            ),
            RefSource(
                4,
                FixedProfile(9),
                FixedProfile(9),
                FixedProfile(100),
                Dict(Coal => 1),
                [
                    SingleInvData(
                        FixedProfile(1000), # capex [€/kW]
                        FixedProfile(200),  # max installed capacity [kW]
                        ContinuousInvestment(FixedProfile(0), FixedProfile(200)), # investment mode
                    ),
                ],
            ),
            RefNetworkNode(
                5,
                FixedProfile(0),
                FixedProfile(5.5),
                FixedProfile(100),
                Dict(NG => 2),
                Dict(Power => 1, CO2 => 0),
                [
                    SingleInvData(
                        FixedProfile(600),  # capex [€/kW]
                        FixedProfile(25),   # max installed capacity [kW]
                        ContinuousInvestment(FixedProfile(0), FixedProfile(25)), # investment mode
                    ),
                    CaptureEnergyEmissions(0.9),
                ],
            ),
            RefNetworkNode(
                6,
                FixedProfile(0),
                FixedProfile(6),
                FixedProfile(100),
                Dict(Coal => 2.5),
                Dict(Power => 1),
                [
                    SingleInvData(
                        FixedProfile(800),  # capex [€/kW]
                        FixedProfile(25),   # max installed capacity [kW]
                        ContinuousInvestment(FixedProfile(0), FixedProfile(25)), # investment mode
                    ),
                    EmissionsEnergy(),
                ],
            ),
            RefStorage{AccumulatingEmissions}(
                7,
                StorCapOpex(FixedProfile(0), FixedProfile(9.1), FixedProfile(100)),
                StorCap(FixedProfile(0)),
                CO2,
                Dict(CO2 => 1, Power => 0.02),
                Dict(CO2 => 1),
                [
                    StorageInvData(
                        charge = NoStartInvData(
                            FixedProfile(0),
                            FixedProfile(600),
                            ContinuousInvestment(FixedProfile(0), FixedProfile(600)),
                            UnlimitedLife(),
                        ),
                        level = NoStartInvData(
                            FixedProfile(500),
                            FixedProfile(600),
                            ContinuousInvestment(FixedProfile(0), FixedProfile(600)),
                            UnlimitedLife(),
                        ),
                    ),
                ],
            ),
            RefNetworkNode(
                8,
                FixedProfile(2),
                FixedProfile(0),
                FixedProfile(0),
                Dict(Coal => 2.5),
                Dict(Power => 1),
                [
                    SingleInvData(
                        FixedProfile(0),    # capex [€/kW]
                        FixedProfile(25),    # max installed capacity [kW]
                        ContinuousInvestment(FixedProfile(2), FixedProfile(2)), # investment mode
                    ),
                    EmissionsEnergy(),
                ],
            ),
            RefStorage{AccumulatingEmissions}(
                9,
                StorCapOpex(FixedProfile(3), FixedProfile(0), FixedProfile(0)),
                StorCap(FixedProfile(5)),
                CO2,
                Dict(CO2 => 1, Power => 0.02),
                Dict(CO2 => 1),
                [
                    StorageInvData(
                        charge = NoStartInvData(
                            FixedProfile(0),
                            FixedProfile(30),
                            ContinuousInvestment(FixedProfile(3), FixedProfile(3)),
                            UnlimitedLife(),
                        ),
                        level = NoStartInvData(
                            FixedProfile(0),
                            FixedProfile(50),
                            ContinuousInvestment(FixedProfile(5), FixedProfile(5)),
                            UnlimitedLife(),
                        ),
                    ),
                ],
            ),
            RefNetworkNode(
                10,
                FixedProfile(0),
                FixedProfile(0),
                FixedProfile(0),
                Dict(Coal => 2.5),
                Dict(Power => 1),
                [
                    SingleInvData(
                        FixedProfile(10000),        # capex [€/kW]
                        FixedProfile(10000),     # max installed capacity [kW]
                        ContinuousInvestment(FixedProfile(0), FixedProfile(10000)),  # investment mode
                    ),
                    EmissionsEnergy(),
                ],
            ),
        ]
        links = [
            Direct(15, nodes[1], nodes[5], Linear())
            Direct(16, nodes[1], nodes[6], Linear())
            Direct(17, nodes[1], nodes[7], Linear())
            Direct(18, nodes[1], nodes[8], Linear())
            Direct(19, nodes[1], nodes[9], Linear())
            Direct(110, nodes[1], nodes[10], Linear())
            Direct(12, nodes[1], nodes[2], Linear())
            Direct(31, nodes[3], nodes[1], Linear())
            Direct(41, nodes[4], nodes[1], Linear())
            Direct(51, nodes[5], nodes[1], Linear())
            Direct(61, nodes[6], nodes[1], Linear())
            Direct(71, nodes[7], nodes[1], Linear())
            Direct(81, nodes[8], nodes[1], Linear())
            Direct(91, nodes[9], nodes[1], Linear())
            Direct(101, nodes[10], nodes[1], Linear())
        ]

        # Creation of the time structure and global data
        T = TwoLevel(4, 1, SimpleTimes(24, 1), op_per_strat = 24)
        em_limits = Dict(NG => FixedProfile(1e6), CO2 => StrategicProfile([450, 400, 350, 300]))
        em_cost = Dict(NG => FixedProfile(0), CO2 => FixedProfile(0))
        modeltype = InvestmentModel(em_limits, em_cost, CO2, 0.07)

        # WIP case structure
        case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)
        return case, modeltype
    end

    case, modeltype = investment_model()
    m = run_model(case, modeltype, HiGHS.Optimizer)

    # Test for the total number of variables
    # (-80 ((6+4)*2*4) compared to 0.5.x as binaries only defined, if required through SparseVariables)
    # (+192 (2*4*24) compared to 0.5.x as stor_discharge_use added as variable)
    @test size(all_variables(m))[1] == 10224

    # Test results
    # (-724 compared to 0.5.x as RefStorage as emission source does not require a charge
    #  capacity any longer in 0.7.x)
    @test round(objective_value(m)) ≈ -302624

    # Test that investments are happening
    𝒯ᴵⁿᵛ = strategic_periods(case[:T])
    𝒩 = case[:nodes]
    𝒩ᴵⁿᵛ = filter(has_investment, filter(!EMB.is_storage, 𝒩))
    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    𝒩ˡᵉᵛᵉˡ = filter(n -> has_investment(n, :level), 𝒩ˢᵗᵒʳ)
    𝒩ᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :charge), 𝒩ˢᵗᵒʳ)

    @test sum(
        sum(value.(m[:cap_add][n, t_inv]) > 0 for n ∈ 𝒩ᴵⁿᵛ)
        for t_inv ∈ 𝒯ᴵⁿᵛ) > 0
    @test sum(
        sum(value.(m[:stor_level_add][n, t_inv]) > 0 for n ∈ 𝒩ˡᵉᵛᵉˡ)
        for t_inv ∈ 𝒯ᴵⁿᵛ) > 0
    @test sum(
        sum(value.(m[:stor_charge_add][n, t_inv]) > 0 for n ∈ 𝒩ᶜʰᵃʳᵍᵉ)
        for t_inv ∈ 𝒯ᴵⁿᵛ) > 0

end

# Set the global to true to suppress the error message
EMB.TEST_ENV = true

@testset "Test checks - InvestmentData" begin

    # Testing, that the checks for NoStartInvData and StartInvData are working
    # - EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)
    @testset "SingleInvData" begin

        function build_simple_graph(;
            cap = FixedProfile(0),
            min_add = FixedProfile(0),
            max_add = FixedProfile(10),
            inv_data = nothing,
        )
            if isnothing(inv_data)
                inv_data = [
                    SingleInvData(
                        FixedProfile(1000),     # capex [€/kW]
                        FixedProfile(30),       # max installed capacity [kW]
                        ContinuousInvestment(min_add, max_add),   # investment mode
                    ),
                ]
            end

            CO2 = ResourceEmit("CO2", 1.0)
            Power = ResourceCarrier("Power", 0.0)
            products = [Power, CO2]

            source = RefSource(
                "-src",
                cap,
                FixedProfile(10),
                FixedProfile(5),
                Dict(Power => 1),
                inv_data,
            )
            sink = RefSink(
                "-snk",
                FixedProfile(20),
                Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e4)),
                Dict(Power => 1),
            )
            nodes = [source, sink]
            links = [Direct("scr-sink", nodes[1], nodes[2], Linear())]
            T = TwoLevel(4, 10, SimpleTimes(4, 1))
            case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

            em_limits = Dict(CO2 => StrategicProfile([450, 400, 350, 300]))
            em_cost = Dict(CO2 => FixedProfile(0))
            modeltype = InvestmentModel(em_limits, em_cost, CO2, 0.05)

            return create_model(case, modeltype)
        end

        # Check that we receive an error if we provide two `InvestmentData`
        inv_data = [
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(30),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(0), FixedProfile(20)), # investment mode
            ),
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(30),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(0), FixedProfile(20)),   # investment mode
            ),
        ]
        @test_throws AssertionError build_simple_graph(;inv_data)

        # Check that we receive an error if the profiles are wrong
        rprofile = RepresentativeProfile([FixedProfile(4)])
        scprofile = ScenarioProfile([FixedProfile(4)])
        oprofile = OperationalProfile(ones(4))

        max_add = oprofile
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = scprofile
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = rprofile
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = StrategicProfile([4])
        @test_throws AssertionError build_simple_graph(;max_add)

        max_add = StrategicProfile([oprofile, oprofile, oprofile, oprofile])
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = StrategicProfile([scprofile, scprofile, scprofile, scprofile])
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = StrategicProfile([rprofile, rprofile, rprofile, rprofile])
        @test_throws AssertionError build_simple_graph(;max_add)

        # Check that we receive an error if the capacity is an operational profile
        cap = OperationalProfile(ones(4))
        @test_throws AssertionError build_simple_graph(;cap)
        inv_data = [SingleInvData(
            FixedProfile(1000),     # capex [€/kW]
            FixedProfile(10),       # max installed capacity [kW]
            cap,                    # initial capacity
            ContinuousInvestment(FixedProfile(0), FixedProfile(20)),   # investment mode
        )]
        @test_throws AssertionError build_simple_graph(;inv_data)

        # Check that we receive an error if the initial capacity is higher than the
        # allowed maximum installed
        cap = FixedProfile(50)
        @test_throws AssertionError build_simple_graph(;cap)
        inv_data = [SingleInvData(
            FixedProfile(1000),     # capex [€/kW]
            FixedProfile(10),       # max installed capacity [kW]
            FixedProfile(50),       # initial capacity
            ContinuousInvestment(FixedProfile(0), FixedProfile(20)),   # investment mode
        )]
        @test_throws AssertionError build_simple_graph(;inv_data)

        # Check that we receive an error if we provide a larger `min_add` than `max_add`
        min_add = FixedProfile(20)
        @test_throws AssertionError build_simple_graph(;min_add)
    end

    # Testing, that the checks for StorageInvData are working
    # - EMB.check_node_data(n::EMB.Storage, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)
    @testset "StorageInvData" begin

        function build_simple_graph(;
            charge_cap = FixedProfile(0),
            level_cap = FixedProfile(0),
            min_add = FixedProfile(0),
            max_add = FixedProfile(10),
            inv_data = nothing,
        )
            if isnothing(inv_data)
                inv_data = [
                    StorageInvData(
                        charge = StartInvData(
                            FixedProfile(20),
                            FixedProfile(30),
                            charge_cap,
                            ContinuousInvestment(min_add, max_add),
                            UnlimitedLife(),
                        ),
                        level = NoStartInvData(
                            FixedProfile(500),
                            FixedProfile(6000),
                            ContinuousInvestment(FixedProfile(5), FixedProfile(600)),
                            UnlimitedLife(),
                        ),
                    ),
                ]
            end

            CO2 = ResourceEmit("CO2", 1.0)
            Power = ResourceCarrier("Power", 0.0)
            products = [Power, CO2]

            source = RefSource(
                "-src",
                FixedProfile(20),
                FixedProfile(10),
                FixedProfile(5),
                Dict(Power => 1),
            )
            storage = RefStorage{CyclicStrategic}(
                "stor",
                StorCapOpexVar(charge_cap, FixedProfile(0)),
                StorCapOpexFixed(level_cap, FixedProfile(100)),
                Power,
                Dict(Power => 1.0),
                Dict(Power => 1.0),
                inv_data,
            )
            sink = RefSink(
                "-snk",
                FixedProfile(20),
                Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e4)),
                Dict(Power => 1),
            )
            nodes = [source, storage, sink]
            links = [
                Direct("src-stor", nodes[1], nodes[2], Linear())
                Direct("src-snk", nodes[1], nodes[3], Linear())
                Direct("stor-snk", nodes[2], nodes[3], Linear())
            ]
            T = TwoLevel(4, 10, SimpleTimes(4, 1))
            case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

            em_limits = Dict(CO2 => StrategicProfile([450, 400, 350, 300]))
            em_cost = Dict(CO2 => FixedProfile(0))
            modeltype = InvestmentModel(em_limits, em_cost, CO2, 0.05)

            return create_model(case, modeltype)
        end

        # Check that we receive an error if we provide the wrong `InvestmentData`
        inv_data = [
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(30),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(0), FixedProfile(20)), # investment mode
            )
        ]
        @test_throws AssertionError build_simple_graph(;inv_data)

        # Check that we receive an error if we provide two `InvestmentData`
        inv_data = [
            StorageInvData(
                charge = NoStartInvData(
                    FixedProfile(20),
                    FixedProfile(30),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(20)),
                ),
                level = NoStartInvData(
                    FixedProfile(500),
                    FixedProfile(600),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(600)),
                ),
            ),
            StorageInvData(
                charge = NoStartInvData(
                    FixedProfile(20),
                    FixedProfile(30),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(20)),
                ),
                level = NoStartInvData(
                    FixedProfile(500),
                    FixedProfile(600),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(600)),
                ),
            ),
        ]
        @test_throws AssertionError build_simple_graph(;inv_data)

        # Check that we receive an error if the profiles are wrong
        rprofile = RepresentativeProfile([FixedProfile(4)])
        scprofile = ScenarioProfile([FixedProfile(4)])
        oprofile = OperationalProfile(ones(4))

        max_add = oprofile
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = scprofile
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = rprofile
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = StrategicProfile([4])
        @test_throws AssertionError build_simple_graph(;max_add)

        max_add = StrategicProfile([oprofile, oprofile, oprofile, oprofile])
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = StrategicProfile([scprofile, scprofile, scprofile, scprofile])
        @test_throws AssertionError build_simple_graph(;max_add)
        max_add = StrategicProfile([rprofile, rprofile, rprofile, rprofile])
        @test_throws AssertionError build_simple_graph(;max_add)

        # Check that we receive an error if the capacity is an operational profile
        charge_cap = OperationalProfile(ones(4))
        @test_throws AssertionError build_simple_graph(;charge_cap)
        level_cap = OperationalProfile(ones(4))
        @test_throws AssertionError build_simple_graph(;level_cap)

        # Check that we receive an error if the initial capacity is higher than the
        # allowed maximum installed
        charge_cap = FixedProfile(50)
        @test_throws AssertionError build_simple_graph(;charge_cap)
        level_cap = FixedProfile(10000)
        @test_throws AssertionError build_simple_graph(;level_cap)

        # Check that we receive an error if we provide a larger `min_add` than `max_add`
        min_add = FixedProfile(20)
        @test_throws AssertionError build_simple_graph(;min_add)
    end
end

# Set the global again to false
EMB.TEST_ENV = false

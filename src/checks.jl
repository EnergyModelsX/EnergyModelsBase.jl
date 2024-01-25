# A constant used to control the behaviour of the @assert_or_log macro.
# If set to true, the macro just adds the error messages as a log message
# if the test fails, without throwing an exception. When set to false, the
# macro just acts as a normal @assert macro, and interrupts the program at
# first failed test.
ASSERTS_AS_LOG = true

# Global vector used to gather the log messages.
logs = []


"""
    assert_or_log(ex, msg)

Macro that extends the behaviour of the `@assert` macro. The switch `ASSERTS_AS_LOG`,
controls if the macro should act as a logger or a normal `@assert`. This macro is
designed to be used to check whether the data provided is consistent.
"""
macro assert_or_log(ex, msg)
    return quote
        if ASSERTS_AS_LOG
            # In this case, the @assert_or_log macro is used only to log
            # the error message if the test fails.
            $(esc(ex)) || push!(logs, $(esc(msg)))
        else
            # In this case, the @assert_or_log macro should just act as
            # a normal @assert, and throw an exception at the first failed assert.
            @assert($(esc(ex)), $(esc(msg)))
        end
    end
end


"""
    check_data(case, modeltype)

Check if the case data is consistent. Use the `@assert_or_log` macro when testing.
Currently only checking node data.
"""
function check_data(case, modeltype::EnergyModel)
    # TODO would it be useful to create an actual type for case, instead of using a Dict with
    # naming conventions? Could be implemented as a mutable in energymodelsbase.jl maybe?

    # TODO this usage of the global vector 'logs' doesn't seem optimal. Should consider using
    #   the actual logging macros underneath instead.
    global logs = []
    log_by_element = Dict()

    for n ∈ case[:nodes]
        # Empty the logs list before each check.
        global logs = []
        check_node(n, case[:T], modeltype)
        check_time_structure(n, case[:T])
        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[n] = logs
    end

    logs = []
    check_model(case, modeltype)
    log_by_element[modeltype] = logs

    if ASSERTS_AS_LOG
        compile_logs(case, log_by_element)
    end
end


"""
    compile_logs(case, log_by_element)

Simple method for showing all log messages.
"""
function compile_logs(case, log_by_element)
    log_message = "\n# LOGS\n"

    for (element, messages) ∈ log_by_element
        if length(messages) > 0
            log_message *= string("\n### ", element, "\n")
        end
        for l ∈ messages
            log_message *= string(" * ", l, "\n")
        end
    end

    log_message *= "\n"

    some_error = sum(length(v) > 0 for (k, v) in log_by_element) > 0
    if some_error
        # Write the messages to file only if there was an error.
        io = open("consistency_log.md", "w")
        println(io, log_message)
        close(io)

        # Print the log to the console.
        @error log_message

        # If there was at least one error in the checks, an exception is thrown.
        throw(AssertionError("Inconsistent case data."))
    end
end


function check_model(case, modeltype::EnergyModel)
    for p ∈ case[:products]
        if isa(p, ResourceEmit)
            @assert_or_log haskey(modeltype.emission_limit, p) "All ResourceEmits requires " *
                "an entry in the dictionary GlobalData.Emission_limit. For $p there is none."
        end
    end
end


"""
    check_time_structure(n::Node, 𝒯)

Check that all fields of a `Node` that are of type `TimeProfile` correspond to the time structure `𝒯`.
"""
function check_time_structure(n::Node, 𝒯)
    for fieldname ∈ fieldnames(typeof(n))
        if isa(getfield(n, fieldname), TimeProfile)
            check_profile_field(n.id, fieldname, value, 𝒯)
        end
    end
end

"""
    check_profile_field(fieldname, value::TimeProfile, 𝒯)

Check that an individual `TimeProfile` corresponds to the time structure `𝒯`.
"""
function check_profile_field(id, fieldname, value::StrategicProfile, 𝒯::TwoLevel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @assert_or_log length(value.vals) == length(𝒯ᴵⁿᵛ) "Field '" * string(fieldname) * "' does not match the strategic structure."
    for t_inv ∈ 𝒯ᴵⁿᵛ
        check_profile_field(id, fieldname, value.vals[t_inv.sp], t_inv.operational)
    end
end
function check_profile_field(id, fieldname, value, 𝒯::TwoLevel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        check_profile_field(id, fieldname, value, t_inv.operational, string(t_inv.sp))
    end
end

function check_profile_field(id, fieldname, value, t_inv, sp)
end
function check_profile_field(
    id,
    fieldname,
    value::OperationalProfile,
    t_inv::SimpleTimes,
    sp
    )
    len_vals = length(value.vals)
    len_simp = length(t_inv)
    println(len_vals-len_simp)
    @assert_or_log len_vals > len_simp "Field '" * string(id, fieldname) * "\
        ' is longer than the operational time structure in strategic period \
        " * sp * ". Its last values $(len_vals - len_simp) will be omitted."
    @assert_or_log len_vals < len_simp "Field '" * string(id, fieldname) * "\
        ' is shorter than the operational time structure in strategic period \
        " * sp * ". I will use the last value for the last $(len_simp - len_vals) \
        operational periods."
end
function check_profile_field(
    id,
    fieldname,
    value::OperationalProfile,
    t_inv::RepresentativePeriods,
    sp
    )
    if sp == "1"
        @warn "Node " * id * ", field name " * fieldname * ":" "Using OperionalProfile with \
            RepresentativePeriods is dangerous, as it may lead to unexpected behaviour. \
            It only works reasonable if all representative periods have an operational \
            time structure of the same length. Otherwise, the last value is repeated. \
            The system is tested for the first representative period."
    end
    rp_1 = collect(repr_periods(t_inv))[1]
    check_profile_field(id, fieldname, value, rp_1.operational, sp)
end

function check_profile_field(
    id,
    fieldname,
    value::RepresentativeProfile,
    t_inv::SimpleTimes,
    sp
    )

    if sp == "1"
        @warn "Node " * id * ", field name " * fieldname * ":" "Using RepresentativeProfile \
            with SimpleTimes is dangerous, as it may lead to unexpected behaviour. \
            In this case, only the first profile is used and tested."
    end
    check_profile_field(id, fieldname, value.vals[1], t_inv, sp)
end
function check_profile_field(
    id,
    fieldname,
    value::RepresentativeProfile,
    t_inv::RepresentativePeriods,
    sp
    )
    for t_rp ∈ t_inv.rep_periods
        check_profile_field(id, fieldname, value.vals[1], t_rp, sp)
    end
end

"""
    check_node(n, 𝒯, modeltype::EnergyModel)

Check that the fields of a `Node` corresponds to required structure.
"""
function check_node(n::Node, 𝒯, modeltype::EnergyModel)
end

function check_node(n::Source, 𝒯, modeltype::EnergyModel)
    @assert_or_log sum(n.cap[t] >= 0 for t ∈ 𝒯) == length(𝒯) "The capacity must be non-negative."
end

function check_node(n::Sink, 𝒯, modeltype::EnergyModel)
    @assert_or_log sum(n.cap[t] >= 0 for t ∈ 𝒯) == length(𝒯) "The capacity must be non-negative."

    @assert_or_log :surplus ∈ keys(n.penalty) &&
                   :deficit ∈ keys(n.penalty) "The entries :surplus and :deficit are required in Sink.penalty"

    if :surplus ∈ keys(n.penalty) && :deficit ∈ keys(n.penalty)
        # The if-condition was checked above.
        @assert_or_log sum(n.penalty[:surplus][t] + n.penalty[:deficit][t] ≥ 0 for t ∈ 𝒯) ==
                    length(𝒯) "An inconsistent combination of :surplus and :deficit lead to infeasible model."
    end

end

# function check_node(n::RefNetworkNodeEmissions, 𝒯, modeltype::EnergyModel)
#     @assert_or_log n.co2_capture ≤ 1 "The field CO2_capture must be less or equal to 1."
#     @assert_or_log n.co2_capture ≥ 0 "The field CO2_capture must be non-negative."
# end

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

Macro that extends the behaviour of the @assert macro. The switch ASSERTS_AS_LOG, 
controls if the macro should act as a logger or a normal @assert. This macro is
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

Check if the case data is consistent. Use the @assert_or_log macro when testing.
Currently only checking node data.
"""
function check_data(case, modeltype)
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

    # TODO 
    #  * check that the timeprofile case[:T] is consistent with the ones used in the nodes.

    if ASSERTS_AS_LOG
        compile_logs(case, log_by_element)
    end
end


"""
    compile_logs(case, log_by_element)

Simple method for showing all log messages.
"""
function compile_logs(case, log_by_element)
    log_message = "\n# LOGS\n\n"
    log_message *= "## Nodes\n"
    for n in case[:nodes]
        if length(log_by_element[n]) > 0
            log_message *= string("\n### ", n, "\n")
            for l in log_by_element[n]
                log_message *= string(" * ", l, "\n")
            end
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


"""
    check_time_structure(n::Node, 𝒯)

Check that all fields of a `Node` that are of type `TimeProfile` correspond to the time structure `𝒯`.
"""
function check_time_structure(n::Node, 𝒯)
    for fieldname ∈ fieldnames(typeof(n))
        if isa(getfield(n, fieldname), TimeProfile)
            check_profile_field(fieldname, getfield(n, fieldname), 𝒯)
        end
    end
end

"""
    check_profile_field(fieldname, value::TimeProfile, 𝒯)

Check that an individual `TimeProfile` corresponds to the time structure `𝒯`.
"""
function check_profile_field(fieldname, value::FixedProfile, 𝒯)
end

function check_profile_field(fieldname, value::StrategicFixedProfile, 𝒯)
    @assert_or_log length(value.vals) == 𝒯.len "Field '" * string(fieldname) * "' does not match the time structure."
end

function check_profile_field(fieldname, value::OperationalFixedProfile, 𝒯)
    @assert_or_log length(value.vals) == 𝒯.operational.len "Field '" * string(fieldname) * "' does not match the time structure."
end

function check_profile_field(fieldname, value::DynamicProfile, 𝒯)
    @assert_or_log size(value.vals) == (𝒯.len, 𝒯.operational.len) "Field '" * string(fieldname) * "' does not match the time structure."

end


"""
    check_node(n, 𝒯, modeltype::EnergyModel)

Check that the fields of a `Node n` corresponds to required structure.
"""
function check_node(n::Node, 𝒯, modeltype::EnergyModel)
end

function check_node(n::Source, 𝒯, modeltype::EnergyModel)
    @assert_or_log sum(n.Cap[t] >= 0 for t ∈ 𝒯) == length(𝒯) "The capacity must be non-negative."
end

function check_node(n::Sink, 𝒯, modeltype::EnergyModel)
    @assert_or_log sum(n.Cap[t] >= 0 for t ∈ 𝒯) == length(𝒯) "The capacity must be non-negative."

    @assert_or_log :Surplus ∈ keys(n.Penalty) &&
                   :Deficit ∈ keys(n.Penalty) "The entries :Surplus and :Deficit are required in Sink.Penalty"

    if :Surplus ∈ keys(n.Penalty) && :Deficit ∈ keys(n.Penalty)
        # The if-condition was checked above.
        @assert_or_log sum(n.Penalty[:Surplus][t] + n.Penalty[:Deficit][t] ≥ 0 for t ∈ 𝒯) ==
                    length(𝒯) "An inconsistent combination of :Surplus and :Deficit lead to infeasible model."
    end

end

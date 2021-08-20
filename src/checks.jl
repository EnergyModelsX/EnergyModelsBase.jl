# A constant used to control the behaviour of the @assert_or_log macro.
# If set to true, the macro just adds the error messages as a log message 
# if the test fails, without throwing an exception. When set to false, the 
# macro just acts as a normal @assert macro, and interrupts the program at 
# first failed test.
ASSERTS_AS_LOG = true

# Global vector used to gather the log messages.
logs = []


" Macro that extends the behaviour of the @assert macro. The switch ASSERTS_AS_LOG, 
    controls if the macro should act as a logger or a normal @assert. This macro is
    designed to be used to check whether the data provided is consistent."
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


" Check if the data is consistent. Use the @assert_or_log macro when testing."
function check_data(data, modeltype)
    # TODO would it be useful to create an actual type for data, instead of using a Dict with 
    # naming conventions? Could be implemented as a mutable in energymodelsbase.jl maybe?
   
    # TODO this usage of the global vector 'logs' doesn't seem optimal. Should consider using 
    #   the actual logging macros underneath instead.
    global logs = []
    log_by_element = Dict()

    for n ∈ data[:nodes]
        # Empty the logs list before each check.
        global logs = []
        check_node(n, data[:T], modeltype)
        check_time_structure(n, data[:T])
        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[n] = logs
    end

    # TODO 
    #  * check that the timeprofile data[:T] is consistent with the ones used in the nodes.

    if ASSERTS_AS_LOG
        compile_logs(data, log_by_element)
    end
end


" Simple methods for showing all log messags. "
function compile_logs(data, log_by_element)
    log_message = "\n# LOGS\n\n"
    log_message *= "## Nodes\n"
    for n in data[:nodes]
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
        println(log_message)

        # If there was at least one error in the checks, an exception is thrown.
        throw(AssertionError("Inconsistent data."))
    end
end


" Check that all fields of a node that is a TimeProfile corresponds to the time structure 𝒯."
function check_time_structure(n::Node, 𝒯)
    for fieldname ∈ fieldnames(typeof(n))
        if isa(getfield(n, fieldname), TimeProfile)
            check_profile_field(fieldname, getfield(n, fieldname), 𝒯)
        end
    end
end

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


function check_node(n::Node, 𝒯, modeltype::OperationalModel)
    # Default fallback method.
end


function check_node(n::Source, 𝒯, modeltype::OperationalModel)
    @assert_or_log sum(n.capacity[t] >= 0 for t ∈ 𝒯) == length(𝒯) "The capacity must be non-negative."
end

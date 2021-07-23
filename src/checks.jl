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
function check_data(data)
    # TODO would it be useful to create an actual type for data, instead of using a Dict with 
    # naming conventions? Could be implemented as a mutable in energymodelsbase.jl maybe?
   
    # TODO this usage of the global vector 'logs' doesn't seem optimal. Should consider using 
    #   the actual logging macros underneath instead.
    global logs = []
    log_by_element = Dict()

    for n ∈ data[:nodes]
        # Empty the logs list before each check.
        global logs = []
        check_node(n, data[:T])
        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[n] = logs
    end

    # TODO 
    #  * check that the timeprofile data[:T] is consistent with the ones used in the nodes.

    compile_logs(data, log_by_element)
end


" Simple methods for showing all log messags. "
function compile_logs(data, log_by_element)
    some_error = sum(length(v) > 0 for (k, v) in log_by_element) > 0
    if ! some_error
        return
    end    
    
    if ASSERTS_AS_LOG
        println("\nLOGS")
        println("==========")
    end

    println("Nodes\n----------")
    for n in data[:nodes]
        if length(log_by_element[n]) > 0
            println("\n", n, "\n----------")
            for l in log_by_element[n]
                println(l)
            end
        end
    end
    println()
   
    # If there was at least one error in the checks, an exception is thrown.
    throw(AssertionError("Inconsistent data."))
end


function check_node(n::Node, 𝒯)
    # Default fallback method.
end


function check_node(n::Source, 𝒯)
    @assert_or_log sum(n.capacity[t] >= 0 for t ∈ 𝒯) == length(𝒯) "The capacity must be non-negative."
end

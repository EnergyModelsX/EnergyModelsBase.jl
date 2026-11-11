# A constant used to control the behaviour of the @assert_or_log macro.
# If set to true, the macro just adds the error messages as a log message
# if the test fails, without throwing an exception. When set to false, the
# macro just acts as a normal @assert macro, and interrupts the program at
# first failed test.
global ASSERTS_AS_LOG = true
global TEST_ENV = false

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
    check_data(case, modeltype::EnergyModel, check_timeprofiles::Bool)

Check if the case data is consistent. Use the `@assert_or_log` macro when testing.
Currently only checking node data.
"""
function check_data(case, modeltype::EnergyModel, check_timeprofiles::Bool)
    # TODO would it be useful to create an actual type for case, instead of using a Dict with
    # naming conventions? Could be implemented as a mutable in energymodelsbase.jl maybe?

    # TODO this usage of the global vector `logs` doesn't seem optimal. Should consider using
    #   the actual logging macros underneath instead.
    global logs = []
    log_by_element = Dict()

    if !check_timeprofiles
        @warn(
            "Checking of the time profiles is deactivated:\n" *
            "Deactivating the checks for the time profiles is strongly discouraged. " *
            "While the model will still run, unexpected results can occur, as well as " *
            "inconsistent case data.\n\n" *
            "Deactivating the checks for the timeprofiles should only be considered, " *
            "when testing new components. In all other instances, it is recommended to " *
            "provide the correct timeprofiles using a preprocessing routine.\n\n" *
            "If timeprofiles are not checked, inconsistencies can occur.",
            maxlog = 1
        )
    end

    # Check the case data. If the case data is not in the correct format, the overall check
    # is cancelled as extractions would not be possible
    check_case_data(case, modeltype, check_timeprofiles)
    log_by_element["Case data"] = logs
    if ASSERTS_AS_LOG
        compile_logs(case, log_by_element)
    end

    # Check the individual elements vector
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    𝒯 = get_time_struct(case)
    for elements ∈ 𝒳ᵛᵉᶜ
        check_elements(log_by_element, elements, 𝒳ᵛᵉᶜ, 𝒯, modeltype, check_timeprofiles)
    end

    logs = []
    check_model(case, modeltype, check_timeprofiles)
    log_by_element["Modeltype"] = logs

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
            log_message *= string("\n### ", element, "\n\n")
        end
        for l ∈ messages
            log_message *= string("* ", l, "\n")
        end
    end

    log_message *= "\n"

    some_error = sum(length(v) > 0 for (k, v) ∈ log_by_element) > 0
    if some_error
        # Only print and write the logs if not in a test environment
        if !TEST_ENV
            # Write the messages to file only if there was an error.
            io = open("consistency_log.md", "w")
            println(io, log_message)
            close(io)

            # Print the log to the console if test is not loaded
            @error log_message
        end

        # If there was at least one error in the checks, an exception is thrown.
        throw(AssertionError("Inconsistent case data."))
    end
end

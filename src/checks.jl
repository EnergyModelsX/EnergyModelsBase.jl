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

    # TODO this usage of the global vector 'logs' doesn't seem optimal. Should consider using
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
    check_case_data(case)
    log_by_element["Case data"] = logs
    if ASSERTS_AS_LOG
        compile_logs(case, log_by_element)
    end

    𝒯 = case[:T]

    for n ∈ case[:nodes]

        # Empty the logs list before each check.
        global logs = []
        check_node(n, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
        for data ∈ node_data(n)
            check_node_data(n, data, 𝒯, modeltype, check_timeprofiles)
        end

        if check_timeprofiles
            check_time_structure(n, 𝒯)
        end
        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[n] = logs
    end

    logs = []
    check_model(case, modeltype::EnergyModel, check_timeprofiles)
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

"""
    check_case_data(case)

Checks the `case` dictionary is in the correct format.

## Checks
- The dictionary requires the keys `:T`, `:nodes`, `:links`, and `:products`.
- The individual keys are of the correct type, that is
  - `:T::TimeStructure`,
  - `:nodes::Vector{<:Node}`,
  - `:links::Vector{<:Link}`, and
  - `:products::Vector{<:Resource}`.
"""
function check_case_data(case)
    case_keys = [:T, :nodes, :links, :products]
    key_map = Dict(
        :T => TimeStructure,
        :nodes => Vector{<:Node},
        :links => Vector{<:Link},
        :products => Vector{<:Resource},
    )
    for key ∈ case_keys
        @assert_or_log(
            haskey(case, key),
            "The `case` dictionary requires the key `:" *
            string(key) *
            "` which is " *
            "not included."
        )
        if haskey(case, key)
            @assert_or_log(
                isa(case[key], key_map[key]),
                "The key `" *
                string(key) *
                "` in the `case` dictionary contains " *
                "other types than the allowed."
            )
        end
    end
end

"""
    check_model(case, modeltype::EnergyModel, check_timeprofiles::Bool)

Checks the `modeltype` .

## Checks
- All `ResourceEmit`s require a corresponding value in the field `emission_limit`.
- The `emission_limit` time profiles cannot have a finer granulation than `StrategicProfile`.
- The `emission_price` time profiles cannot have a finer granulation than `StrategicProfile`.

## Conditional checks (if `check_timeprofiles=true`)
- The profiles in `emission_limit` have to have the same length as the number of strategic
  periods.
- The profiles in `emission_price` have to have the same length as the number of strategic
  periods.
"""
function check_model(case, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(case[:T])

    # Check for inclusion of all emission resources
    for p ∈ case[:products]
        if isa(p, ResourceEmit)
            @assert_or_log(
                haskey(emission_limit(modeltype::EnergyModel), p),
                "All `ResourceEmit`s require an entry in the dictionary " *
                "`emission_limit`. For $p there is none."
            )
        end
    end

    for p ∈ keys(emission_limit(modeltype::EnergyModel))
        em_limit = emission_limit(modeltype, p)
        # Check for the strategic periods
        if isa(em_limit, StrategicProfile) && check_timeprofiles
            @assert_or_log(
                length(em_limit.vals) == length(𝒯ᴵⁿᵛ),
                "The timeprofile provided for resource `" *
                string(p) *
                "` in the field " *
                "`emission_limit` does not match the strategic structure."
            )
        end

        # Check for potential indexing problems
        message =
            "are not allowed for the resource: " *
            string(p) *
            " in the Dictionary " *
            "`emission_limit`."
        check_strategic_profile(em_limit, message)
    end

    for p ∈ keys(emission_price(modeltype::EnergyModel))
        em_limit = emission_price(modeltype, p)
        # Check for the strategic periods
        if isa(em_limit, StrategicProfile) && check_timeprofiles
            @assert_or_log(
                length(em_limit.vals) == length(𝒯ᴵⁿᵛ),
                "The timeprofile provided for resource `" *
                string(p) *
                "` in the field " *
                "`emission_price` does not match the strategic structure."
            )
        end

        # Check for potential indexing problems
        message =
            "are not allowed for the resource: " *
            string(p) *
            " in the Dictionary " *
            "`emission_price`."
        check_strategic_profile(em_limit, message)
    end
end

"""
    check_time_structure(n::Node, 𝒯)

Check that all fields of a `Node` that are of type `TimeProfile` correspond to the time
structure `𝒯`.
"""
function check_time_structure(n::Node, 𝒯)
    for fieldname ∈ fieldnames(typeof(n))
        value = getfield(n, fieldname)
        if isa(value, TimeProfile)
            check_profile(fieldname, value, 𝒯)
        end
    end
end

"""
    check_profile(fieldname, value::TimeProfile, 𝒯)

Check that an individual `TimeProfile` corresponds to the time structure `𝒯`.
It currently does not include support for identifying `OperationalScenarios`.
"""
function check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    len_vals = length(value.vals)
    len_simp = length(𝒯ᴵⁿᵛ)
    if len_vals > len_simp
        message = "' is longer than the strategic time structure. \
        Its last $(len_vals - len_simp) value(s) will be omitted."
    elseif len_vals < len_simp
        message = "' is shorter than the strategic time structure. It will use the last \
        value for the last $(len_simp - len_vals) strategic period(s)."
    end
    @assert_or_log len_vals == len_simp "Field '" * string(fieldname) * message
    for t_inv ∈ 𝒯ᴵⁿᵛ
        check_profile(
            fieldname,
            value.vals[minimum([t_inv.sp, length(value.vals)])],
            t_inv.operational,
            t_inv.sp,
        )
    end
end
function check_profile(fieldname, value, 𝒯::TwoLevel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        check_profile(fieldname, value, t_inv.operational, t_inv.sp)
    end
end

"""
    check_profile(fieldname, value::TimeProfile, ts::TimeStructure, sp)

Check that an individual `TimeProfile` corresponds to the time structure `ts` in strategic
period `sp`. The function flow is designed to provide errors in all situations in which the
the `TimeProfile` does not correspond to the chosen `TimeStructure` through the application
of the `@assert_or_log` macro.

Examples for inconsistent combinations:

```julia
ts = SimpleTimes(3, 1)

# A too long OperationalProfile resulting in omitting the last 2 values
value = OperationalProfile([1, 2, 3, 4, 5])

# A too short OperationalProfile resulting in repetition of the last value once
value = OperationalProfile([1, 2])
```

If you use a more detailed TimeProfile than the TimeStructure, it will you provide you with
a warning, *e.g.*, using `RepresentativeProfile` without `RepresentativePeriods`.

It currently does not include support for identifying `OperationalProfile`s.
"""
function check_profile(fieldname, value::OperationalProfile, ts::SimpleTimes, sp)
    len_vals = length(value.vals)
    len_simp = length(ts)
    if len_vals > len_simp
        message =
            "' in strategic period $(sp) is longer " *
            "than the operational time structure. " *
            "Its last $(len_vals - len_simp) value(s) will be omitted."
    elseif len_vals < len_simp
        message =
            "' in strategic period $(sp) is shorter " *
            "than the operational time structure. It will use the last value for the last " *
            "$(len_simp - len_vals + 1) operational period(s)."
    end
    @assert_or_log len_vals == len_simp "Field '" * string(fieldname) * message
end
function check_profile(fieldname, value::OperationalProfile, ts::RepresentativePeriods, sp)
    for t_rp ∈ repr_periods(ts)
        check_profile(fieldname, value, t_rp.operational, sp)
    end
end

function check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, sp)
    if sp == 1
        @warn(
            "Using `RepresentativeProfile` with `SimpleTimes` is dangerous, as it may " *
            "lead to unexpected behaviour. " *
            "In this case, only the first profile is used in the model and tested."
        )
    end
    check_profile(fieldname, value.vals[1], ts, sp)
end
function check_profile(
    fieldname,
    value::RepresentativeProfile,
    ts::RepresentativePeriods,
    sp,
)
    len_vals = length(value.vals)
    len_simp = length(repr_periods(ts))
    if len_vals > len_simp
        message =
            "' in strategic period $(sp) is longer " *
            "than the representative time structure in strategic period $(sp). " *
            "Its last values $(len_vals - len_simp) will be omitted."
    elseif len_vals < len_simp
        message =
            "' in strategic period $(sp) is longer " *
            "than the representative time structure in strategic period $(sp). " *
            "It will use the last value for the last $(len_simp - len_vals + 1) " *
            "representative period(s)."
    end
    @assert_or_log len_vals == len_simp "Field '" * string(fieldname) * message
    for t_rp ∈ repr_periods(ts)
        check_profile(
            fieldname,
            value.vals[minimum([t_rp.rp, length(value.vals)])],
            t_rp.operational,
            sp,
        )
    end
end
check_profile(fieldname, value, ts, sp) = nothing

"""
    check_strategic_profile(time_profile::TimeProfile, message::String)

Function for checking that an individual `TimeProfile` does not include the wrong type for
strategic indexing.

## Checks
- `TimeProfile`s accessed in `StrategicPeriod`s cannot include `OperationalProfile`,
  `ScenarioProfile`, or `RepresentativeProfile` as this is not allowed through indexing
  on the `TimeProfile`.
"""
function check_strategic_profile(time_profile::TimeProfile, message::String)
    # Check on the highest level
    bool_sp = check_strat_sub_profile(time_profile, message, true)

    if isa(time_profile, StrategicProfile)
        for l1_profile ∈ time_profile.vals
            sub_msg = "in strategic profiles " * message
            bool_sp = check_strat_sub_profile(l1_profile, sub_msg, bool_sp)
        end
    end

    return bool_sp
end
function check_strat_sub_profile(sub_profile::TimeProfile, sub_msg::String, bool_sp::Bool)
    @assert_or_log(
        !isa(sub_profile, OperationalProfile),
        "Operational profiles " * sub_msg
    )
    @assert_or_log(!isa(sub_profile, ScenarioProfile), "Scenario profiles " * sub_msg)
    @assert_or_log(
        !isa(sub_profile, RepresentativeProfile),
        "Representative profiles " * sub_msg
    )

    bool_sp *=
        !isa(sub_profile, OperationalProfile) &&
        !isa(sub_profile, ScenarioProfile) &&
        !isa(sub_profile, RepresentativeProfile)
    return bool_sp
end


"""
    check_representative_profile(time_profile::TimeProfile, message::String)

Function for checking that an individual `TimeProfile` does not include the wrong type for
representative periods indexing.

## Input
- `time_profile` - The time profile that should be checked.
- `message` - A message that should be printed after the type of profile.

## Checks
- `TimeProfile`s accessed in `RepresentativePeriod`s cannot include `OperationalProfile`
  or `ScenarioProfile` as this is not allowed through indexing on the `TimeProfile`.
"""
function check_representative_profile(time_profile::TimeProfile, message::String)
    # Check on the highest level
    bool_rp = check_repr_sub_profile(time_profile, message, true)

    # Iterate through the strategic profiles, if existing
    if isa(time_profile, StrategicProfile)
        for l1_profile ∈ time_profile.vals
            sub_msg = "in strategic profiles " * message
            bool_rp = check_repr_sub_profile(l1_profile, sub_msg, bool_rp)
            if isa(l1_profile, RepresentativeProfile)
                for l2_profile ∈ l1_profile.vals
                    sub_msg = "in representative profiles in strategic profiles " * message
                    bool_rp = check_repr_sub_profile(l2_profile, sub_msg, bool_rp)
                end
            end
        end
    end

    # Iterate through the representative profiles, if existing
    if isa(time_profile, RepresentativeProfile)
        for l1_profile ∈ time_profile.vals
            sub_msg = "in representative profiles " * message
            bool_rp = check_repr_sub_profile(l1_profile, sub_msg, bool_rp)
        end
    end
    return bool_rp
end
function check_repr_sub_profile(sub_profile::TimeProfile, sub_msg::String, bool_rp::Bool)
    @assert_or_log(
        !isa(sub_profile, OperationalProfile),
        "Operational profiles " * sub_msg
    )
    @assert_or_log(!isa(sub_profile, ScenarioProfile), "Scenario profiles " * sub_msg)

    bool_rp *= !isa(sub_profile, OperationalProfile) && !isa(sub_profile, ScenarioProfile)
    return bool_rp
end

"""
    check_scenario_profile(time_profile::TimeProfile, message::String)

Function for checking that an individual `TimeProfile` does not include the wrong type for
scenario indexing.

## Checks
- `TimeProfile`s accessed in `RepresentativePeriod`s cannot include `OperationalProfile`
  or `ScenarioProfile` as this is not allowed through indexing on the `TimeProfile`.
"""
function check_scenario_profile(time_profile::TimeProfile, message::String)
    # Check on the highest level
    bool_osc = check_osc_sub_profile(time_profile, message, true)

    # Iterate through the strategic profiles, if existing
    if isa(time_profile, StrategicProfile)
        for l1_profile ∈ time_profile.vals
            sub_msg = "in strategic profiles " * message
            bool_osc = check_osc_sub_profile(l1_profile, sub_msg, bool_osc)
            if isa(l1_profile, RepresentativeProfile)
                for l2_profile ∈ l1_profile.vals
                    sub_msg = "in representative profiles in strategic profiles " * message
                    bool_osc = check_osc_sub_profile(l2_profile, sub_msg, bool_osc)
                    if isa(l2_profile, ScenarioProfile)
                        for l3_profile ∈ l2_profile.vals
                            sub_msg = "in scenario profiles in representative profiles in strategic profiles " * message
                            bool_osc = check_osc_sub_profile(l3_profile, sub_msg, bool_osc)
                        end
                    end
                end
            elseif isa(l1_profile, ScenarioProfile)
                for l2_profile ∈ l1_profile.vals
                    sub_msg = "in scenario profiles in strategic profiles " * message
                    bool_osc = check_osc_sub_profile(l2_profile, sub_msg, bool_osc)
                end
            end
        end
    end

    # Iterate through the representative profiles, if existing
    if isa(time_profile, RepresentativeProfile)
        for l1_profile ∈ time_profile.vals
            sub_msg = "in representative profiles " * message
            bool_osc = check_osc_sub_profile(l1_profile, sub_msg, bool_osc)
            if isa(l1_profile, ScenarioProfile)
                for l2_profile ∈ l1_profile.vals
                    sub_msg = "in scenario profiles in representative profiles " * message
                    bool_osc = check_osc_sub_profile(l2_profile, sub_msg, bool_osc)
                end
            end
        end
    end

    # Iterate through the scenario profiles, if existing
    if isa(time_profile, ScenarioProfile)
        for l1_profile ∈ time_profile.vals
            sub_msg = "in scenario profiles " * message
            bool_osc = check_osc_sub_profile(l1_profile, sub_msg, bool_osc)
        end
    end
    return bool_scp
end
function check_osc_sub_profile(sub_profile::TimeProfile, sub_msg::String, bool_scp::Bool)
    @assert_or_log(
        !isa(sub_profile, OperationalProfile),
        "Operational profiles " * sub_msg
    )
    bool_scp *= !isa(sub_profile, OperationalProfile)
    return bool_scp
end

"""
    check_node(n::Node, 𝒯, modeltype::EnergyModel)

Check that the fields of a `Node` corresponds to required structure.
"""
function check_node(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) end
"""
    check_node(n::Availability, 𝒯, modeltype::EnergyModel)

This method checks that an `Availability` node is valid. By default, that does not include
any checks.
"""
function check_node(n::Availability, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) end
"""
    check_node(n::Source, 𝒯, modeltype::EnergyModel)

This method checks that a `Source` node is valid.

These checks are always performed, if the user is not creating a new method. Hence, it is
important that a new `Source` type includes at least the same fields as in the [`RefSource`](@ref)
node or that a new `Source` type receives a new method for `check_node`.

## Checks
 - The field `cap` is required to be non-negative.
 - The values of the dictionary `output` are required to be non-negative.
 - The value of the field `fixed_opex` is required to be non-negative and
   accessible through a `StrategicPeriod` as outlined in the function
   [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref).
"""
function check_node(n::Source, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        sum(capacity(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        sum(outputs(n, p) ≥ 0 for p ∈ outputs(n)) == length(outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end
"""
    check_node(n::NetworkNode, 𝒯, modeltype::EnergyModel)

This method checks that a `NetworkNode` node is valid.

These checks are always performed, if the user is not creating a new method. Hence, it is
important that a new `NetworkNode` type includes at least the same fields as in the
[`RefNetworkNode`(@ref) node or that a new `NetworkNode` type receives a new method for `check_node`.

## Checks
 - The field `cap` is required to be non-negative.
 - The values of the dictionary `input` are required to be non-negative.
 - The values of the dictionary `output` are required to be non-negative.
 - The value of the field `fixed_opex` is required to be non-negative and
   accessible through a `StrategicPeriod` as outlined in the function
   [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref).
"""
function check_node(n::NetworkNode, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        sum(capacity(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        sum(inputs(n, p) ≥ 0 for p ∈ inputs(n)) == length(inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        sum(outputs(n, p) ≥ 0 for p ∈ outputs(n)) == length(outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end
"""
    check_node(n::Storage, 𝒯, modeltype::EnergyModel)

This method checks that a `Storage` node is valid.

These checks are always performed, if the user is not creating a new method. Hence, it is
important that a new `Storage` type includes at least the same fields as in the
[`RefStorage`](@ref) node or that a new `Storage` type receives a new method for `check_node`.

## Checks
 - The `TimeProfile` of the field `capacity` in the type in the field `charge` is required
   to be non-negative if the chosen composite type has the field `capacity`.
 - The `TimeProfile` of the field `capacity` in the type in the field `level` is required
   to be non-negative`.
 - The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
   to be non-negative if the chosen composite type has the field `capacity`.
 - The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
   accessible through a `StrategicPeriod` as outlined in the function
   [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref) for the chosen composite type .
 - The values of the dictionary `input` are required to be non-negative.
 - The values of the dictionary `output` are required to be non-negative.
"""
function check_node(n::Storage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    par_charge = charge(n)
    par_level = level(n)
    par_discharge = discharge(n)

    if isa(par_charge, UnionCapacity)
        @assert_or_log(
            sum(capacity(par_charge, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
            "The charge capacity must be non-negative."
        )
    end
    if isa(par_charge, UnionOpexFixed)
        check_fixed_opex(par_charge, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    @assert_or_log(
        sum(capacity(par_level, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The level capacity must be non-negative."
    )
    if isa(par_level, UnionOpexFixed)
        check_fixed_opex(par_level, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    if isa(par_discharge, UnionCapacity)
        @assert_or_log(
            sum(capacity(par_discharge, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
            "The charge capacity must be non-negative."
        )
    end
    if isa(par_discharge, UnionOpexFixed)
        check_fixed_opex(par_discharge, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    @assert_or_log(
        sum(inputs(n, p) ≥ 0 for p ∈ inputs(n)) == length(inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        sum(outputs(n, p) ≥ 0 for p ∈ outputs(n)) == length(outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
end
"""
    check_node(n::Sink, 𝒯, modeltype::EnergyModel)

This method checks that a `Sink` node is valid.

These checks are always performed, if the user is not creating a new method. Hence, it is
important that a new `Sink` type includes at least the same fields as in the [`RefSink`](@ref)
node or that a new `Source` type receives a new method for `check_node`.

## Checks
 - The field `cap` is required to be non-negative.
 - The values of the dictionary `input` are required to be non-negative.
 - The dictionary `penalty` is required to have the keys `:deficit` and `:surplus`.
 - The sum of the values `:deficit` and `:surplus` in the dictionary `penalty` has to be
   non-negative to avoid an infeasible model.
"""
function check_node(n::Sink, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    @assert_or_log(
        sum(capacity(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        sum(inputs(n, p) ≥ 0 for p ∈ inputs(n)) == length(inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        :surplus ∈ keys(n.penalty) && :deficit ∈ keys(n.penalty),
        "The entries :surplus and :deficit are required in the field `penalty`"
    )

    if :surplus ∈ keys(n.penalty) && :deficit ∈ keys(n.penalty)
        # The if-condition was checked above.
        @assert_or_log(
            sum(surplus_penalty(n, t) + deficit_penalty(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
            "An inconsistent combination of `:surplus` and `:deficit` leads to an infeasible model."
        )
    end
end
"""
    check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles::Bool)

Checks that the fixed opex value follows the given `TimeStructure`.
This check requires that a function `opex_fixed(n)` is defined for the input `n` which
returns a `TimeProfile`.

## Checks
- The `opex_fixed` time profile cannot have a finer granulation than `StrategicProfile`.

## Conditional checks (if `check_timeprofiles=true`)
- The profiles in `opex_fixed` have to have the same length as the number of strategic
  periods.
"""
function check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles::Bool)
    if isa(opex_fixed(n), StrategicProfile) && check_timeprofiles
        @assert_or_log(
            length(opex_fixed(n).vals) == length(𝒯ᴵⁿᵛ),
            "The timeprofile provided for the field `opex_fixed` does not match the " *
            "strategic structure."
        )
    end

    # Check for potential indexing problems
    message = "are not allowed for the field `opex_fixed`."
    bool_sp = check_strategic_profile(opex_fixed(n), message)

    # Check that the value is positive in all cases
    if bool_sp
        @assert_or_log(
            sum(opex_fixed(n, t_inv) ≥ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ),
            "The fixed OPEX must be non-negative."
        )
    end
end

"""
    check_node_data(n::Node, data::Data, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_node_data(n::Node, data::EmissionsData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the included `Data` types of a `Node` corresponds to required structure.
This function will always result in a multiple error message, if several instances of the
same supertype is loaded.

## Checks `EmissionsData`
- Each node can only have a single `EmissionsData`.
- Time profiles for process emissions, if present.
- The value of the field `co2_capture` is required to be in the range ``[0, 1]``, if
  [`CaptureData`](@ref) is used.
"""
function check_node_data(
    n::Node,
    data::EmissionsData,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    em_data = filter(data -> typeof(data) <: EmissionsData, node_data(n))
    @assert_or_log(
        length(em_data) ≤ 1,
        "Only one `EmissionsData` can be added to each node."
    )

    # No checks necessary for a standard `EmissionsEnergy`
    isa(data, EmissionsEnergy) && return

    for p ∈ process_emissions(data)
        value = process_emissions(data, p)
        !check_timeprofiles && continue
        !isa(value, TimeProfile) && continue
        check_profile(string(p) * " process emissions", value, 𝒯)
    end
end
function check_node_data(
    n::Node,
    data::CaptureData,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    em_data = filter(data -> typeof(data) <: EmissionsData, node_data(n))
    @assert_or_log(
        length(em_data) ≤ 1,
        "Only one `EmissionsData` can be added to each node."
    )

    for p ∈ process_emissions(data)
        value = process_emissions(data, p)
        !check_timeprofiles && continue
        !isa(value, TimeProfile) && continue
        check_profile(string(p) * " process emissions", value, 𝒯)
    end
    @assert_or_log(
        co2_capture(data) ≤ 1,
        "The field `co2_capture` in `CaptureData` must be less or equal to 1."
    )
    @assert_or_log(
        co2_capture(data) ≥ 0,
        "The field `co2_capture` in `CaptureData` must be non-negative."
    )
end
check_node_data(n::Node, data::Data, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) =
    nothing

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
    check_case_data(case)
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

"""
    check_case_data(case)

Checks the `case` dictionary is in the correct format.

## Checks
- The individual elements vector must be unique, that it is not possible to have two vector
  of nodes within the elements vector.
- Check that the coupling functions do return elements and not only an empty vector
"""
function check_case_data(case)
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    get_vect_type(vec::Vector{T}) where {T} = T
    vec_types = [get_vect_type(x) for x ∈ 𝒳ᵛᵉᶜ]

    for type_1 ∈ vec_types
        for type_2 ∈ vec_types
            if type_1 ≠ type_2
                @assert_or_log(
                    !(type_1 <: type_2),
                    "It is not possible to have both `$(type_1)` and `$(type_2)` vectors in the case file."
                )
            end
        end
    end

    𝒳ᵛᵉᶜ_𝒳ᵛᵉᶜ = get_couplings(case)
    for couple ∈ 𝒳ᵛᵉᶜ_𝒳ᵛᵉᶜ
        for cpl ∈ couple
            @assert_or_log(
                !isempty(cpl(case)),
                "The function `$cpl` in the couplings field returns an empty vector."
            )
        end
    end

end

"""
    check_elements(log_by_element, _::Vector{<:AbstractElement}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_elements(log_by_element, 𝒩::Vector{<:Node}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_elements(log_by_element, ℒ::Vector{<:Link}}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Checks the individual elements vector. It has implemented methods for both `Vector{<:Node}`
and Vector{<:Link}.


!!! note "Node methods"
    All nodes are checked through the functions
    - [`check_node`](@ref) to identify problematic input,
    - [`check_node_data`](@ref EnergyModelsBase.check_node_data(n::Node, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool))
      issues in the provided additional data, and
    - [`check_time_structure`](@ref) to identify time profiles at the highest level that
      are not equivalent to the provided timestructure.

!!! note "Links methods"
    All links are checked through the functions
    - [`check_link`](@ref) to identify problematic input,
    - [`check_link_data`](@ref EnergyModelsBase.check_link_data(l::Link, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool))
      to identify issues in the provided additional data, and
    - [`check_time_structure`](@ref) to identify time profiles at the highest level that
      are not equivalent to the provided timestructure.

    In addition, all links are directly checked:

    - The nodes in the fields `:from` and `:to` are present in the Node vector as extracted
      through the function [`get_nodes`](@ref).
    - The node in the field `:from` has output and the node in the field `:to` has input.
    - The [`inputs`](@ref) of the link are included in the [`outputs`](@ref) of the `:from`
      node and the [`outputs`](@ref) of the link are included in the [`inputs`](@ref) of the
      `:to` node.
"""
function check_elements(
    log_by_element,
    _::Vector{<:AbstractElement},
    𝒳ᵛᵉᶜ,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
end
function check_elements(
    log_by_element,
    𝒩::Vector{<:Node},
    𝒳ᵛᵉᶜ,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
    for n ∈ 𝒩
        # Empty the logs list before each check.
        global logs = []
        check_node(n, 𝒯, modeltype, check_timeprofiles)
        for data ∈ node_data(n)
            check_node_data(n, data, 𝒯, modeltype, check_timeprofiles)
        end

        check_timeprofiles && check_time_structure(n, 𝒯)

        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[n] = logs
    end
end
function check_elements(
    log_by_element,
    ℒ::Vector{<:Link},
    𝒳ᵛᵉᶜ,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
    for l ∈ ℒ
        # Empty the logs list before each check.
        global logs = []

        # Check the connections of the link
        𝒩  = get_nodes(𝒳ᵛᵉᶜ)
        @assert_or_log(
            l.from ∈ 𝒩,
            "The node in the field `:from` is not included in the Node vector. As a consequence," *
            "the link would not be utilized in the model."
        )
        @assert_or_log(
            has_output(l.from),
            "The node in the field `:from` does not allow for outputs."
        )
        @assert_or_log(
            all(p_in ∈ outputs(l.from) for p_in ∈ inputs(l)),
            "Not all resources specifed as `inputs` of the link are specified as `outputs` " *
            "of the node in the field `:from`. As a consequence, the link could potentially " *
            "be not utilized in the model."
        )
        @assert_or_log(
            l.to ∈ 𝒩,
            "The node in the field `:to` is not included in the Node vector. As a consequence," *
            "the link would not be utilized in the model."
        )
        @assert_or_log(
            has_input(l.to),
            "The node in the field `:to` does not allow for inputs."
        )
        @assert_or_log(
            all(p_out ∈ inputs(l.to) for p_out ∈ outputs(l)),
            "Not all resources specifed as `outputs` of the link are specified as `inputs` " *
            "of the node in the field `:to`. As a consequence, the link could potentially " *
            "not be utilized in the model."
        )

        # Check the links, the link data, and the time structure
        check_link(l, 𝒯, modeltype, check_timeprofiles)
        for data ∈ link_data(l)
            check_link_data(l, data, 𝒯, modeltype, check_timeprofiles)
        end
        check_timeprofiles && check_time_structure(l, 𝒯)
        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[l] = logs
    end
end

"""
    check_model(case, modeltype::EnergyModel, check_timeprofiles::Bool)

Checks the `modeltype` .

## Checks
- All `ResourceEmit`s require a corresponding value in the field `emission_limit`.
- The `emission_limit` time profiles cannot have a finer granulation than `StrategicProfile`.

## Conditional checks (if `check_timeprofiles=true`)
- The profiles in `emission_limit` have to have the same length as the number of strategic
  periods.
- The profiles in `emission_price` have to follow the time structure as outlined in
  [`check_profile`](@ref).
"""
function check_model(case, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯 = get_time_struct(case)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Check for inclusion of all emission resources
    for p ∈ get_products(case)
        if isa(p, ResourceEmit)
            @assert_or_log(
                haskey(emission_limit(modeltype), p),
                "All `ResourceEmit`s require an entry in the dictionary " *
                "`emission_limit`. For $p there is none."
            )
        end
    end

    for p ∈ keys(emission_limit(modeltype))
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
            "are not allowed for the resource `" *
            string(p) *
            "` in the dictionary " *
            "`emission_limit`."
        check_strategic_profile(em_limit, message)
    end

    for p ∈ keys(emission_price(modeltype))
        em_price = emission_price(modeltype, p)
        check_timeprofiles || continue
        check_profile("emission_price[" * string(p) * "]", em_price, 𝒯)
    end
end

"""
    check_time_structure(x::AbstractElement, 𝒯)

Check that all fields of a `AbstractElement` that are of type `TimeProfile` correspond to
the time structure `𝒯`.
"""
function check_time_structure(x::AbstractElement, 𝒯)
    for fieldname ∈ fieldnames(typeof(x))
        value = getfield(x, fieldname)
        if isa(value, TimeProfile)
            check_profile(fieldname, value, 𝒯)
        end
    end
end

"""
    check_profile(fieldname, value::TimeProfile, 𝒯::TwoLevel)
    check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevel)
    check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::TwoLevel)

    check_profile(fieldname, value::TimeProfile, 𝒯::TwoLevelTree)
    check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevelTree)
    check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::TwoLevelTree)

Check that an individual `TimeProfile` corresponds to the time structure `𝒯`. The individual
checks are depending on the profile type and the time structure.
"""
function check_profile(fieldname, value::TimeProfile, 𝒯::TwoLevel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        p_msg = "strategic period $(t_inv.sp)"
        check_profile(fieldname, value, t_inv.operational, p_msg)
    end
end
function check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    len_vals = length(value.vals)
    len_ts = length(𝒯ᴵⁿᵛ)
    if len_vals > len_ts
        message = "` is longer than the strategic time structure. " *
            "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message = "` is shorter than the strategic time structure. It will use the last " *
            "value for the last $(len_ts - len_vals) strategic period(s)."
    end
    @assert_or_log(
        len_vals == len_ts, "The `TimeProfile` of field `" * string(fieldname) * message
    )
    for t_inv ∈ 𝒯ᴵⁿᵛ
        p_msg = "strategic period $(t_inv.sp)"
        check_profile(
            fieldname,
            value.vals[minimum([t_inv.sp, length(value.vals)])],
            t_inv.operational,
            p_msg,
        )
    end
end
function check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::TwoLevel)
    @warn(
        "Using `StrategicStochasticProfile` with `TwoLevel` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the profiles of the first scenario are used in the model and " *
        "tested.",
        maxlog = 1
    )
    prof = StrategicProfile([op_prof[1] for op_prof ∈ value.vals])
    check_profile(fieldname, prof, 𝒯)
end
function check_profile(fieldname, value::TimeProfile, 𝒯::TwoLevelTree)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        p_msg = "branch $(t_inv.branch) in strategic period $(t_inv.sp)"
        check_profile(fieldname, value, t_inv.operational, p_msg)
    end
end
function check_profile(fieldname, value::StrategicProfile, 𝒯::TwoLevelTree)
    𝒯ˢˢᶜ = strategic_scenarios(𝒯)
    t_inv_vec = []

    for ssc ∈ 𝒯ˢˢᶜ
        𝒯ᴵⁿᵛ = strategic_periods(ssc)
        len_vals = length(value.vals)
        len_ts = length(𝒯ᴵⁿᵛ)
        if len_vals > len_ts
            message = "` is longer than strategic scenario $(ssc.scen). " *
                "Its last $(len_vals - len_ts) value(s) will be omitted."
        elseif len_vals < len_ts
            message = "` is shorter than strategic scenario $(ssc.scen). It will use the " *
                "last value for the last $(len_ts - len_vals) strategic period(s)."
        end
        @assert_or_log(
            len_vals == len_ts, "The `TimeProfile` of field `" * string(fieldname) * message,
        )
        for t_inv ∈ 𝒯ᴵⁿᵛ
            t_inv ∈ t_inv_vec && continue
            push!(t_inv_vec, t_inv)

            p_msg = "branch $(t_inv.branch) in strategic period $(t_inv.sp)"
            check_profile(
                fieldname,
                value.vals[minimum([t_inv.sp, length(value.vals)])],
                t_inv.operational,
                p_msg,
            )
        end
    end
end
function check_profile(fieldname, value::StrategicStochasticProfile, 𝒯::TwoLevelTree)
    # Check for the number of strategic periods
    len_vals = length(value.vals)
    len_ts = n_strat_per(𝒯)
    if len_vals > len_ts
        message = "` is longer than the strategic time structure. " *
            "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message = "` is shorter than the strategic time structure. It will use the last " *
            "value for the last $(len_ts - len_vals) strategic period(s)."
    end
    @assert_or_log(
        len_vals == len_ts,
        "The `TimeProfile` of field `" * string(fieldname) * message,
    )

    # Check each individual branch
    for sp ∈ 1:n_strat_per(𝒯)
        pre_msg = "` in strategic period $(sp) has "
        len_vals = length(value.vals[minimum([sp, length(value.vals)])])
        len_branches = n_branches(𝒯, sp)
        if len_vals > len_branches
            message = pre_msg * "more branches than the time structure. " *
                "Its last $(len_vals - len_branches) value(s) will be omitted."
        elseif len_vals < len_branches
            message = pre_msg * "less branches than the time structure. It will use the " *
                "last value for the last $(len_branches - len_vals) branche(s)."
        end
        @assert_or_log(
            len_vals == len_branches,
            "The `TimeProfile` of field `" * string(fieldname) * message,
        )
    end

    # Check the sub profiles
    for t_inv ∈ strategic_periods(𝒯)
        p_msg = "branch $(t_inv.branch) in strategic period $(t_inv.sp)"
        sp_prof = value.vals[minimum([t_inv.sp, length(value.vals)])]
        check_profile(
            fieldname,
            sp_prof[minimum([t_inv.branch, length(sp_prof)])],
            t_inv.operational,
            p_msg,
        )
    end
end

"""
    check_profile(fieldname, value::TimeProfile, ts::TimeStructure, p_msg)

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

If you use a more detailed `TimeProfile` than the `TimeStructure`, it will provide you with
a warning, *e.g.*, using `RepresentativeProfile` without `RepresentativePeriods`.
"""
function check_profile(fieldname, value::OperationalProfile, ts::SimpleTimes, p_msg)
    len_vals = length(value.vals)
    len_ts = length(ts)
    if len_vals > len_ts
        message =
            "` in " * p_msg * " is longer than the operational time structure. " *
            "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message =
            "` in " * p_msg * " is shorter than the operational time structure. " *
            "It will use the last value for the last $(len_ts - len_vals + 1) " *
            "operational period(s)."
    end
    @assert_or_log(
        len_vals == len_ts,
        "The `TimeProfile` of field `" * string(fieldname) * message
    )
end
function check_profile(fieldname, value::OperationalProfile, ts::OperationalScenarios, p_msg)
    for t_osc ∈ opscenarios(ts)
        p_msg_osc = "operational scenario $(t_osc.scen) in " * p_msg
        check_profile(fieldname, value, t_osc.operational, p_msg_osc)
    end
end
function check_profile(fieldname, value::OperationalProfile, ts::RepresentativePeriods, p_msg)
    for t_rp ∈ repr_periods(ts)
        p_msg_rp = "representative period $(t_rp.rp) in " * p_msg
        check_profile(fieldname, value, t_rp.operational, p_msg_rp)
    end
end

function check_profile(fieldname, value::ScenarioProfile, ts::SimpleTimes, p_msg)
    @warn(
        "Using `ScenarioProfile` with `SimpleTimes` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested.",
        maxlog = 1
    )
    check_profile(fieldname, value.vals[1], ts, p_msg)
end
function check_profile(fieldname, value::ScenarioProfile, ts::OperationalScenarios, p_msg)
    len_vals = length(value.vals)
    len_ts = length(opscenarios(ts))
    if len_vals > len_ts
        message =
            "` in " * p_msg * " is longer than the operational scenario time structure. " *
            "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message =
            "` in " * p_msg * " is shorter than the operational scenario time structure. " *
            "It will use the last value for the last $(len_ts - len_vals + 1) " *
            "operational period(s)."
    end
    @assert_or_log(
        len_vals == len_ts,
        "The `TimeProfile` of field `" * string(fieldname) * message
    )
    for t_osc ∈ opscenarios(ts)
        p_msg_osc = "operational scenario $(t_osc.scen) in " * p_msg
        check_profile(
            fieldname,
            value.vals[minimum([t_osc.scen, length(value.vals)])],
            t_osc.operational,
            p_msg_osc,
        )
    end
end
function check_profile(fieldname, value::ScenarioProfile, ts::RepresentativePeriods, p_msg)
    for t_rp ∈ repr_periods(ts)
        p_msg_rp = "representative period $(t_rp.rp) in " * p_msg
        check_profile(fieldname, value, t_rp.operational, p_msg_rp)
    end
end

function check_profile(fieldname, value::RepresentativeProfile, ts::SimpleTimes, p_msg)
    @warn(
        "Using `RepresentativeProfile` with `SimpleTimes` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested.",
        maxlog = 1
    )
    check_profile(fieldname, value.vals[1], ts, p_msg)
end
function check_profile(fieldname, value::RepresentativeProfile, ts::OperationalScenarios, p_msg)
    @warn(
        "Using `RepresentativeProfile` with `OperationalScenarios` is dangerous, " *
        "as it may lead to unexpected behaviour. " *
        "In this case, only the first profile is used in the model and tested.",
        maxlog = 1
    )
    check_profile(fieldname, value.vals[1], ts, p_msg)
end
function check_profile(
    fieldname,
    value::RepresentativeProfile,
    ts::RepresentativePeriods,
    p_msg,
)
    len_vals = length(value.vals)
    len_ts = length(repr_periods(ts))
    if len_vals > len_ts
        message =
        "` in " * p_msg * " is longer than the representative time structure. " *
        "Its last $(len_vals - len_ts) value(s) will be omitted."
    elseif len_vals < len_ts
        message =
        "` in " * p_msg * " is shorter than the representative time structure. " *
        "It will use the last value for the last $(len_ts - len_vals + 1) " *
        "operational period(s)."
    end
    @assert_or_log(
        len_vals == len_ts,
        "The `TimeProfile` of field `" * string(fieldname) * message
    )
    for t_rp ∈ repr_periods(ts)
        p_msg_rp = "in representative period $(t_rp.rp) in " * p_msg
        check_profile(
            fieldname,
            value.vals[minimum([t_rp.rp, length(value.vals)])],
            t_rp.operational,
            p_msg_rp,
        )
    end
end
check_profile(fieldname, value, ts, p_msg) = nothing

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
    check_node(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the fields of a `Node` corresponds to required structure.

The default approach calls the subroutine [`check_node_default`](@ref) which provides the
user with default checks for [`Source`](@ref), [`NetworkNode`](@ref), [`Availability`](@ref),
[`Storage`](@ref), and [`Sink`](@ref) nodes.

!!! tip "Creating a new node type"
    When developing a new node with new checks, it is important to create a new method for
    `check_node`. You can then call within this function the default tests for the corresponding
    supertype through calling the function [`check_node_default`](@ref).
"""
check_node(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) =
    check_node_default(n, 𝒯, modeltype, check_timeprofiles)
"""
    check_node_default(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that a `Node` node is valid. By default, that does not include
any checks.
"""
function check_node_default(n::Node, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) end
"""
    check_node_default(n::Availability, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that an `Availability` node is valid. By default, that does not include
any checks.
"""
function check_node_default(n::Availability, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) end
"""
    check_node_default(n::Source, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Subroutine that can be utilized in other packages for incorporating the standard tests for
a [`Source`](@ref) node.

## Checks
- The field `cap` is required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.
- The value of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref).
"""
function check_node_default(n::Source, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        all(outputs(n, p) ≥ 0 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end
"""
    check_node_default(n::NetworkNode, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Subroutine that can be utilized in other packages for incorporating the standard tests for
a [`NetworkNode`](@ref) node.

## Checks
- The field `cap` is required to be non-negative.
- The values of the dictionary `input` are required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.
- The value of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref).
"""
function check_node_default(n::NetworkNode, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        all(inputs(n, p) ≥ 0 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        all(outputs(n, p) ≥ 0 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
end
"""
    check_node_default(n::Storage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Subroutine that can be utilized in other packages for incorporating the standard tests for
a [`Storage`](@ref) node.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required
  to be non-negative if the chosen composite type has the field `capacity`.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required
  to be non-negative`.
- The `TimeProfile` of the field `capacity` in the type in the field `discharge` is required
  to be non-negative if the chosen composite type has the field `capacity`.
- The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)`](@ref) for the chosen composite type.
- The values of the dictionary `input` are required to be non-negative.
- The specified storage [`Resource`](@ref) must be included in the dictionary `input`.
- The values of the dictionary `output` are required to be non-negative.
- The specified storage [`Resource`](@ref) must be included in the dictionary `output`.
"""
function check_node_default(n::Storage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    par_charge = charge(n)
    par_level = level(n)
    par_discharge = discharge(n)

    if isa(par_charge, UnionCapacity)
        @assert_or_log(
            all(capacity(par_charge, t) ≥ 0 for t ∈ 𝒯),
            "The charge capacity must be non-negative."
        )
    end
    if isa(par_charge, UnionOpexFixed)
        check_fixed_opex(par_charge, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    @assert_or_log(
        all(capacity(par_level, t) ≥ 0 for t ∈ 𝒯),
        "The level capacity must be non-negative."
    )
    if isa(par_level, UnionOpexFixed)
        check_fixed_opex(par_level, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    if isa(par_discharge, UnionCapacity)
        @assert_or_log(
            all(capacity(par_discharge, t) ≥ 0 for t ∈ 𝒯),
            "The discharge capacity must be non-negative."
        )
    end
    if isa(par_discharge, UnionOpexFixed)
        check_fixed_opex(par_discharge, 𝒯ᴵⁿᵛ, check_timeprofiles)
    end
    has_input(n) && @assert_or_log(
        all(inputs(n, p) ≥ 0 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    has_input(n) && @assert_or_log(
        storage_resource(n) ∈ inputs(n),
        "The stored resource must be included in the Dictionary `input`."
    )
    has_output(n) && @assert_or_log(
        all(outputs(n, p) ≥ 0 for p ∈ outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    has_output(n) && @assert_or_log(
        storage_resource(n) ∈ outputs(n),
        "The stored resource must be included in the Dictionary `output`."
    )
end

"""
    check_node_default(n::Sink, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Subroutine that can be utilized in other packages for incorporating the standard tests for
a [`Sink`](@ref) node.

## Checks
- The field `cap` is required to be non-negative.
- The values of the dictionary `input` are required to be non-negative.
- The dictionary `penalty` is required to have the keys `:deficit` and `:surplus`.
- The sum of the values `:deficit` and `:surplus` in the dictionary `penalty` has to be
  non-negative to avoid an infeasible model.
"""
function check_node_default(n::Sink, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    @assert_or_log(
        all(capacity(n, t) ≥ 0 for t ∈ 𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        all(inputs(n, p) ≥ 0 for p ∈ inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        :surplus ∈ keys(n.penalty) && :deficit ∈ keys(n.penalty),
        "The entries `:surplus` and `:deficit` are required in the field `penalty`."
    )

    if :surplus ∈ keys(n.penalty) && :deficit ∈ keys(n.penalty)
        @assert_or_log(
            all(surplus_penalty(n, t) + deficit_penalty(n, t) ≥ 0 for t ∈ 𝒯),
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
            all(opex_fixed(n, t_inv) ≥ 0 for t_inv ∈ 𝒯ᴵⁿᵛ),
            "The fixed OPEX must be non-negative."
        )
    end
end

"""
    check_node_data(n::Node, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_node_data(n::Node, data::EmissionsData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the included `ExtensionData` types of a `Node` correspond to required structure.

## Checks `EmissionsData`
- Each node can only have a single `EmissionsData`.
- Time profiles for process emissions, if present.
- The value of the field `co2_capture` is required to be in the range ``[0, 1]``, if
  [`CaptureData`](@ref) is used.
"""
check_node_data(n::Node, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) =
    nothing
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
        check_timeprofiles || continue
        isa(value, TimeProfile) || continue
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
        check_timeprofiles || continue
        isa(value, TimeProfile) || continue
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

"""
    check_link(l::Link, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
    check_link(l::Direct, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the fields of a [`Link`](@ref) corresponds to required structure. The default
functionality does not check anthing, aside from the checks performed in [`check_elements`](@ref).

## Checks `Direct`
- The functions [`inputs`](@ref) and [`outputs`](@ref) must be non-empty.

!!! tip "Creating a new link type"
    When developing a new link with new checks, it is important to create a new method for
    `check_link`.
"""
check_link(l::Link, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) = nothing
function check_link(l::Direct, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

    @assert_or_log(
        !isempty(link_res(l)),
        "The functions `inputs` and `outputs` return an empty `Vector`. This implies that " *
        "the nodes in the fields `:from` and `:to` do not have common `Resources` as " *
        "`outputs` and `inputs`, respectively. Hence, the link will not be used."
    )
end
"""
    check_link_data(l::Link, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

Check that the included `ExtensionData` types of a `Link` correspond to required structure.
"""
check_link_data(l::Link, data::ExtensionData, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool) =
    nothing

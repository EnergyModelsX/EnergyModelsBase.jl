"""
    run_model(case::Dict, model::EnergyModel, optimizer)

Take the `case` data as a dictionary and the `model` and build and optimize the model.
Returns the solved JuMP model.

The dictionary requires the keys:
 - `:nodes::Vector{Node}`
 - `:links::Vector{Link}`
 - `:products::Vector{Resource}`
 - `:T::TimeStructure`
"""
function run_model(case::Dict, model, optimizer; check_timeprofiles = true)
    @debug "Run model" optimizer

    m = create_model(case, model; check_timeprofiles)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        set_optimizer_attribute(m, MOI.Silent(), true)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @warn "No optimizer given"
    end
    return m
end


"""
    collect_types(types_list)

Return a Dict of all the give types_list and their supertypes. The keys in the dictionary
are the types, and their corresponding value is the number in the type hierarchy.

E.g., `Node` is at the top and will thus have the value 1. Types just below `Node` will have
value 2, and so on.
"""
function collect_types(types_list)
    types = Dict()
    for n ∈ types_list
        # Skip the node if we have already traversed its ancestors.
        if n ∈ keys(types)
            continue
        end
        types[n] = 1

        parent = supertype(n)
        if parent == Any
            continue
        end

        # If the parent is already added to the list, we can skip it.
        if parent ∉ types_list
            ancestors = collect_types([parent])
            # Increase the rank of the current node by adding the rank of the ancestor with
            # highes rank.
            types[n] += reduce(max, values(ancestors))
            types = merge(types, ancestors)
        end
    end
    return types
end


"""
    sort_types(types_list::Dict)

Sort the result of `collect_types` and return a vector where a supertype comes before
all its subtypes.
"""
function sort_types(types_list::Dict)
    # Find the maximum node-rank, that is the largest number of subtypes from the `Node`
    # type. This is the maximum number stored in the supplied dictionary.
    max_rank = reduce(max, values(types_list))

    # A vector which will contain numbers used to sort the types_list.
    num = []
    for (T, ranking) ∈ types_list
        # Find the number of entries of type T. The type T with the most entries will be a
        # broader T, and must be a supertype (or a cousin) of a type with fewer entries.
        value = length(filter(n -> isa(n, T), keys(types_list)))
        # The ranking is used as the tie-break measure. If we have two types with the same
        # number of entries, we have to make sure the supertype is sorted before the subtype.
        # The highest rank number must be sorted after the lower one (since this means it is
        # lower in the type hierarchy). Since the value added will only work as a tie break,
        # we make sure it is below 1 by dividing by (max_rank + 1).
        value_ex = value + (1 - ranking / (max_rank + 1))
        push!(num, value_ex)
    end

    # We sort the vector of numbers `num` from largest to smallest value, and get the
    # indexes of the sorted order.
    sorted_idx = sortperm(num, rev = true)
    # Get the types from the dictionary as a vector.
    types = [n for n in keys(types_list)]
    # Use the indexes of the sorted order to sort the order of the types.
    sorted_types_list = types[sorted_idx]
    return sorted_types_list
end

"""
    previous_level(
        m,
        n::Storage,
        prev_pers::PreviousPeriods,
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

Returns the level used as previous level of a `Storage` node depending on the type of
[`PreviousPeriods`](@ref).

The basic functionality is used in the case when the previous operational period is a
`TimePeriod`, in which case it just returns the previous operational period.
"""
function previous_level(
    m,
    n::Storage,
    prev_pers::PreviousPeriods,
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    # Previous storage level, as there are no changes
    return @expression(m, m[:stor_level][n, op_per(prev_pers)])
end
"""
    previous_level(
        m,
        n::Storage,
        prev_pers::PreviousPeriods{<:NothingPeriod, Nothing, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational and representative period are `Nothing`, the function
returns the cyclic constraints within a strategic period. This is achieved through calling a
subfunction [`previous_level_sp`](@ref) to avoid method ambiguities.
"""
function previous_level(
    m,
    n::Storage,
    prev_pers::PreviousPeriods{<:NothingPeriod,Nothing,Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    return previous_level_sp(m, n, cyclic_pers, modeltype::EnergyModel)
end
"""
    previous_level(
        m,
        n::Storage,
        prev_pers::PreviousPeriods{<:NothingPeriod, Nothing, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational and representative period are `Nothing` and the storage node
is an [`AccumulatingEmissions`](@ref) storage node, the function returns a value of 0.
"""
function previous_level(
    m,
    n::Storage{AccumulatingEmissions},
    prev_pers::PreviousPeriods{<:NothingPeriod,Nothing,Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)
    # Return the previous storage level as 0 for the reference storage unit
    return @expression(m, 0)
end
"""
    previous_level(
        m,
        n::Storage,
        prev_pers::PreviousPeriods{<:NothingPeriod, <:TS.AbstractRepresentativePeriod, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational period is `Nothing`, the previous representative period an
`AbstractRepresentativePeriod` and the last period is an `AbstractRepresentativePeriod`,
then the time structure *does* include `RepresentativePeriods`.

The cyclic default constraints returns the value at the end of the *previous* representative
period while accounting for the number of  repetitions of the representative period.
"""
function previous_level(
    m,
    n::Storage,
    prev_pers::PreviousPeriods{<:NothingPeriod,<:TS.AbstractRepresentativePeriod,Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    # Return the previous storage level with the increase in the representative period
    return @expression(
        m,
        # Initial storage in previous rp
        m[:stor_level][n, first(rep_per(prev_pers))] -
        m[:stor_level_Δ_op][n, first(rep_per(prev_pers))] *
        duration(first(rep_per(prev_pers))) +
        # Increase in previous representative period
        m[:stor_level_Δ_rp][n, rep_per(prev_pers)]
    )
end
"""
    previous_level(
        m,
        n::Storage{CyclicRepresentative},
        prev_pers::PreviousPeriods{<:NothingPeriod, <:TS.AbstractRepresentativePeriod, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational period is `Nothing` and the previous representative period an
`AbstractRepresentativePeriod` then the time structure *does* include `RepresentativePeriods`.

The cyclic constraint for a [`CyclicRepresentative`](@ref) storage nodereturns the value at
the end of the *current* representative period.
"""
function previous_level(
    m,
    n::Storage{CyclicRepresentative},
    prev_pers::PreviousPeriods{<:NothingPeriod,<:TS.AbstractRepresentativePeriod,Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)
    # Return the previous storage level based on cyclic constraints within the representative
    # period
    return @expression(m, m[:stor_level][n, last(current_per(cyclic_pers))])
end
"""
    previous_level_sp(
        m,
        n::Storage{<:Cyclic},
        cyclic_pers::CyclicPeriods,
        modeltype
    )

Returns the previous period in the case of the first operational period (in the first
representative period) of a strategic period.

The default functionality in the case of a [`Cyclic`](@ref) storage node in a `TimeStructure`
without `RepresentativePeriods` returns the last operational period in the strategic period.
"""
function previous_level_sp(m, n::Storage{<:Cyclic}, cyclic_pers::CyclicPeriods, modeltype::EnergyModel)
    # Return the previous storage level based on cyclic constraints
    last_op = last(current_per(cyclic_pers))
    return @expression(m, m[:stor_level][n, last_op])
end
"""
    previous_level_sp(
        m,
        n::Storage{CyclicStrategic},
        cyclic_pers::CyclicPeriods{<:TS.AbstractRepresentativePeriod},
        modeltype::EnergyModel,
    )

When a [`CyclicStrategic`](@ref) `Storage` node is coupled with a `TimeStructure` containing
`RepresentativePeriods`, then the function calculates the level at the beginning of the
first representative period through the changes in the level in the last representative
period.
"""
function previous_level_sp(
    m,
    n::Storage{CyclicStrategic},
    cyclic_pers::CyclicPeriods{<:TS.AbstractRepresentativePeriod},
    modeltype::EnergyModel,
)
    # Extract the last representative period from the type CyclicPeriods
    last_rp = last_per(cyclic_pers)

    # Return the previous storage level based on cyclic constraints when representative
    # periods are included
    return @expression(
        m,
        # Initial storage in previous representative period
        m[:stor_level][n, first(last_rp)] -
        m[:stor_level_Δ_op][n, first(last_rp)] * duration(first(last_rp)) +
        # Increase in previous representative period
        m[:stor_level_Δ_rp][n, last_rp]
    )
end
"""
    previous_level_sp(
        m,
        n::Storage{CyclicRepresentative},
        cyclic_pers::CyclicPeriods{<:TS.AbstractRepresentativePeriod},
        modeltype::EnergyModel,
    )

When a [`CyclicRepresentative`](@ref) `Storage` node is coupled with a `TimeStructure` containing
`RepresentativePeriods`, then the function returns the previous level as the level at the
end of the current representative period.
"""
function previous_level_sp(
    m,
    n::Storage{CyclicRepresentative},
    cyclic_pers::CyclicPeriods{<:TS.AbstractRepresentativePeriod},
    modeltype::EnergyModel,
)
    # Extract the last operational period in the representative period from the type
    # `CyclicPeriods`
    last_op = last(current_per(cyclic_pers))

    # Return the previous storage level based on cyclic constraints within the representative
    # period
    return @expression(m, m[:stor_level][n, last_op])
end

"""
    multiple(t_inv, t)

Provide a simplified function for returning the combination of the functions
duration(t) * multiple_strat(t_inv, t) * probability(t)
"""
multiple(t_inv, t) = duration(t) * multiple_strat(t_inv, t) * probability(t)

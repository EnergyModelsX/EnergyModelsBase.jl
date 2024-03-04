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
function run_model(case::Dict, model::EnergyModel, optimizer; check_timeprofiles=true)
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
        if  parent ∉ types_list
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
    sorted_idx = sortperm(num, rev=true)
    # Get the types from the dictionary as a vector.
    types = [n for n in keys(types_list)]
    # Use the indexes of the sorted order to sort the order of the types.
    sorted_types_list = types[sorted_idx]
    return sorted_types_list
end

"""
    multiple(t_inv, t)

Provide a simplified function for returning the combination of the functions
duration(t) * multiple_strat(t_inv, t) * probability(t)
"""
multiple(t_inv, t) = duration(t) * multiple_strat(t_inv, t) * probability(t)

# function previous_level(
#     m,
#     n::Storage,
#     prev_pers::PrevPeriods{Nothing, Nothing, Nothing},
#     t::TS.TimePeriod,
#     modeltype::EnergyModel,
# )
#     @info "Frist operational period in the first strategic period"

# end

function previous_level(
    m,
    n::Storage,
    prev_pers::PrevPeriods{<:nt, Nothing, Nothing},
    t::TS.TimePeriod,
    modeltype::EnergyModel,
)

    # Return the previous storage level based on cyclic constraints when representative
    # periods are included
    return @expression(
        m,
        # Initial storage in previous representative period
        m[:stor_level][n, first(prev_pers.last)] -
        m[:stor_level_Δ_op][n, first(prev_pers.last)] * duration(first(prev_pers.last)) +
        # Increase in previous representative period
        m[:stor_level_Δ_rp][n, prev_pers.last]
    )

    # # Return the previous storage level as 0 in the first representative period of the first
    # # strategic period
    # return @expression(m, 0)
end
function previous_level(
    m,
    n::RefStorage{R},
    prev_pers::PrevPeriods{<:nt, Nothing, Nothing},
    t::TS.TimePeriod,
    modeltype::EnergyModel,
) where {R<:ResourceEmit}

    # Return the previous storage level as 0 in the first representative period of the first
    # strategic period
    return @expression(m, 0)
end
function previous_level(
    m,
    n::Storage,
    prev_pers::PrevPeriods{<:nt, <:TS.AbstractStrategicPeriod, Nothing},
    t::TS.TimePeriod,
    modeltype::EnergyModel,
)

    # Return the previous storage level based on cyclic constraints
    return @expression(
        m,
        # Storage level in previous operational period
        m[:stor_level][n, prev_pers.last]
    )

    # # Return the previous storage level as 0 in the first representative period of the first
    # # strategic period
    # return @expression(m, 0)
end
function previous_level(
    m,
    n::RefStorage{R},
    prev_pers::PrevPeriods{<:nt, <:TS.AbstractStrategicPeriod, Nothing},
    t::TS.TimePeriod,
    modeltype::EnergyModel,
) where {R<:ResourceEmit}

    # Return the previous storage level as 0 for the reference storage unit
    return @expression(m, 0)
end
function previous_level(
    m,
    n::Storage,
    prev_pers::PrevPeriods{<:nt, <:TS.AbstractRepresentativePeriod, Nothing},
    t::TS.TimePeriod,
    modeltype::EnergyModel,
)

    # Return the previous storage level with the increase in the representative period
    return @expression(
        m,
        # Initial storage in previous rp
        m[:stor_level][n, first(prev_pers.rp)] -
        m[:stor_level_Δ_op][n, first(prev_pers.rp)] * duration(first(prev_pers.rp)) +
        # Increase in previous representative period
        m[:stor_level_Δ_rp][n, prev_pers.rp]
    )
end

function previous_level(
    m,
    n::Storage,
    prev_pers::PrevPeriods,
    t::TS.TimePeriod,
    modeltype::EnergyModel,
)

    # Previous storage level, as there are no changes
    return @expression(m, m[:stor_level][n, prev_pers.op])
end

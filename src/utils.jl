"""
    run_model(case::Dict, optimizer)

Take the case data as a dictionary and build and optimize the model.

The dictionary requires the keys:
 - :nodes ::Vector{Node}
 - :links ::Vector{Link}
 - :products ::Vector{Resource} 
 - :T ::TimeStructure
"""
function run_model(case::Dict, model::EnergyModel, optimizer)
   @debug "Run model" optimizer

    m = create_model(case, model)

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
    collect_node_types(node_types)

Return a Dict of all the give node_types and their supertypes. The keys in the dictionary
are the types, and their corresponding value is the number in the type hierarchy.

I.e., Node is at the top and will thus have the value 1. Types just below Node will have
value 2, and so on.
"""
function collect_node_types(node_types)
    types = Dict()
    for n ∈ node_types
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
        if  parent ∉ node_types
            ancestors = collect_node_types([parent])
            # Increase the rank of the current node by adding the rank of the ancestor with
            # highes rank.
            types[n] += reduce(max, values(ancestors))
            types = merge(types, ancestors)
        end
    end
    return types
end


"""
    sort_node_types(node_types::Dict)

Sort the result of `collect_node_types` and return a vector where a supertype comes before
all its subtypes.
"""
function sort_node_types(node_types::Dict)
    # Find the maximum node-rank, that is the largest number of subtypes from the `Node`
    # type. This is the maximum number stored in the supplied dictionary.
    max_rank = reduce(max, values(node_types))

    # A vector which will contain numbers used to sort the node_types.
    num = []
    for (T, ranking) ∈ node_types
        # Find the number of nodes of type T. The type T with the most nodes will be a
        # broader T, and must be a supertype (or a cousin) of a type with fewer nodes.
        value = length(filter(n -> isa(n, T), keys(node_types)))
        # The ranking is used as the tie-break measure. If we have two types with the same
        # number of nodes, we have to make sure the supertype is sorted before the subtype.
        # The highest rank number must be sorted after the lower one (since this means it is
        # lower in the type hierarchy). Since the value added will only work as a tie break,
        # we make sure it is below 1 by dividing by (max_rank + 1).
        value_ex = value + (1 - ranking / (max_rank + 1))
        push!(num, value_ex)
    end

    # We sort the vector of numbers `num` from largest to smallest value, and get the
    # indexes of the sorted order.
    sorted_idx = sortperm(num, rev=true)
    # Get the nodes-types from the dictionary as a vector.
    nodes = [n for n in keys(node_types)]
    # Use the indexes of the sorted order to sort the order of the node types.
    sorted_node_types = nodes[sorted_idx]
    return sorted_node_types
end

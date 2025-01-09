"""
    EMXCase

Type representing a case in `EnergyModelsBase`. It replaces the previously used dictionary
for providing the input to a model.

# Fields
- **`T::TimeStructure`** is the time structure of the model.
- **`products::Vector{<:Resource}`** are the resources that should be incorporated into the
  model.
  !!! tip
      It must containt all [`ResourceEmit`](@ref) in `EnergyModelsBase`, but it is not
      necessary that the [`ResourceCarrier`](@ref) are included. It is however advisable to
      include all resources.
- **`elements::Vector{Vector{<:AbstractElement}}`** are the vectors of [`AbstractElement`](@ref)
  that should be included in the analysis. It must contain at least vectors of nodes and
  links for an analysis to be useful.
- **`couplings::Vector{Vector}`** are the couplings between the individual function element
  types. These elements are represented through a corresponding function, *e.g.*, [`f_nodes`](@ref)
  or [`f_links`](@ref)
- **`misc::Dict`** is a dictionary that can be utilized for providing additional high level
  data in the existing format in the case of a new function for case creation. It is
  conditional through the application of a constructor.

!!! tip "Couplings"
    `EnergyModelsBase` requires the coupling of links and nodes. Hence, as a default
    approach, it adds the coupling

    ```julia
    couplings = [[f_nodes, f_links]]
    ```

    in an external constructor if the couplings are not specified.
"""
struct EMXCase
    T::TimeStructure
    products::Vector{<:Resource}
    elements::Vector{Vector}
    couplings::Vector{Vector{Function}}
    misc::Dict
    function EMXCase(
        T::TimeStructure,
        products::Vector{<:Resource},
        elements::Vector{Vector},
        couplings::Vector{Vector{Function}},
        misc::Dict,
    )
        if all(isa(els, Vector{<:AbstractElement}) for els ∈ elements)
            new(T, products, elements, couplings, misc)
        else
            throw(
                ArgumentError(
                    "It is not possible to provide a vector to the field elements that " *
                    "is not a `Vector{<:AbstractElement}`.",
                ),
            )
        end
    end
end
function EMXCase(
    T::TimeStructure,
    products::Vector{<:Resource},
    elements::Vector{Vector},
    couplings::Vector{Vector{Function}},
    )
    return EMXCase(T, products, elements, couplings, Dict())
end

"""
    f_time_struct(case::EMXCase)

Returns the time structure of the EMXCase `case`.
"""
f_time_struct(case::EMXCase) = case.T

"""
    f_products(case::EMXCase)

Returns the vector of products of the EMXCase `case`.
"""
f_products(case::EMXCase) = case.products

"""
    f_elements_vec(case::EMXCase)

Returns the vector of element vectors of the EMXCase `case`.
"""
f_elements_vec(case::EMXCase) = case.elements

"""
    f_nodes(case::EMXCase)

Returns the vector of nodes of the EMXCase `case`.
"""
f_nodes(case::EMXCase) = filter(el -> isa(el, Vector{<:Node}), f_elements_vec(case))[1]

"""
    f_links(case::EMXCase)

Returns the vector of links of the EMXCase `case`.
"""
f_links(case::EMXCase) = filter(el -> isa(el, Vector{<:Link}), f_elements_vec(case))[1]

function EMXCase(
    T::TimeStructure,
    products::Vector{<:Resource},
    elements::Vector{Vector},
    )
    couplings = [[f_nodes, f_links]]
    return EMXCase(T, products, elements, couplings, Dict())
end
function EMXCase(
    T::TimeStructure,
    products::Vector{<:Resource},
    elements::Vector{Vector},
    misc::Dict,
    )
    couplings = [[f_nodes, f_links]]
    return EMXCase(T, products, elements, couplings, misc)
end

#=
    Support for >= and >
=#
const UnionGT{T} = Union{Strictly{T, MOI.GreaterThan{T}}, MOI.GreaterThan{T}}

function supports_concreteB(concrete_B)
    added_constraints = MOIB.added_constraint_types(concrete_B)
    length(added_constraints) > 1 && return false
    # The inner constraint should not create any variable (might have unexpected consequences)
    return isempty(MOIB.added_constrained_variable_types(concrete_B))
end

function get_num_vars(fct::SAF)
    return length(fct.terms)
end

function get_num_vars(fct::VAF)
    return length(fct.terms)
end

function get_num_vars(fct::MOI.VectorOfVariables)
    return length(fct.variables)
end

"""
    map_function(bridge, fct, set)

Default for when set is not needed so return `MOIBC.map_function(bridge, fct)`
If the set is needed a specific method should be implemented
"""
function map_function(
    bridge::Type{<:MOIBC.AbstractBridge},
    fct,
    set
)
    MOIBC.map_function(bridge, fct)
end


"""
    added_constraint_types(bridge, set)

Default for when set is not needed so return `MOIBC.added_constraint_types(bridge)`
If the set is needed a specific method should be implemented
"""
function added_constraint_types(
    B::Type{<:MOIBC.AbstractBridge},
    S,
)
    return MOIB.added_constraint_types(B)
end
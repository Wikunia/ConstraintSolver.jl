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
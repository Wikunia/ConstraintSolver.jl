"""
    equal(variables::Vector{Variable})

Create a BasicConstraint which will later be used by `equal(com, constraint)` \n
Can be used i.e by `add_constraint!(com, CS.equal([x,y,z])`.
"""
function equal(variables::Vector{Variable})
    constraint = BasicConstraint(
        0, # idx will be changed later
        var_vector_to_moi(variables),
        EqualSet(length(variables)),
        Int[v.idx for v in variables],
        Int[], # pvals will be filled later
        false, # `enforce_bound` can be changed later but should be set to false by default
        nothing, 
        zero(UInt64), # hash will be filled in the next step
    )
    constraint.hash = constraint_hash(constraint)
    return constraint
end

"""
    Base.:(==)(x::Variable, y::Variable)

Create a BasicConstraint which will later be used by `equal(com, constraint)` \n
Can be used i.e by `add_constraint!(com, x == y)`.
"""
function Base.:(==)(x::Variable, y::Variable)
    variables = [x, y]
    bc = BasicConstraint(
        0, # idx will be changed later
        var_vector_to_moi(variables),
        EqualSet(2),
        Int[x.idx, y.idx],
        Int[], # pvals will be filled later
        false, # `enforce_bound` can be changed later but should be set to false by default
        nothing,
        zero(UInt64), # hash will be filled in the next step
    )
    bc.hash = constraint_hash(bc)
    return bc
end

"""
    prune_constraint!(com::CS.CoM, constraint::BasicConstraint, fct::MOI.VectorOfVariables, set::EqualSet; logs = true)

Reduce the number of possibilities given the equality constraint which sets all variables in `MOI.VectorOfVariables` to the same value.
Return a ConstraintOutput object and throws a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::BasicConstraint,
    fct::MOI.VectorOfVariables,
    set::EqualSet;
    logs = true,
)
    indices = constraint.indices

    search_space = com.search_space
    # is only needed if we want to set more
    if length(indices) > 2
        fixed_vals, unfixed_indices = fixed_vs_unfixed(search_space, indices)

        fixed_vals_set = Set(fixed_vals)
        # check if one value is used more than once
        if length(fixed_vals_set) > 1
            logs && @warn "The problem is infeasible"
            return false
        elseif length(fixed_vals_set) == 0
            return true
        end

        # otherwise prune => set all variables to fixed value
        for i in unfixed_indices
            idx = indices[i]
            feasible = fix!(com, search_space[idx], fixed_vals[1])
            if !feasible
                return false
            end
        end
    else # faster for two variables
        v1 = search_space[indices[1]]
        v2 = search_space[indices[2]]
        fixed_v1 = isfixed(v1)
        fixed_v2 = isfixed(v2)
        if !fixed_v1 && !fixed_v2
            return true
        elseif fixed_v1 && fixed_v2
            if CS.value(v1) != CS.value(v2)
                return false
            end
            return true
        end
        # one is fixed and one isn't
        if fixed_v1
            fix_v = 2
            feasible = fix!(com, v2, CS.value(v1))
            if !feasible
                return false
            end
        else
            feasible = fix!(com, v1, CS.value(v2))
            if !feasible
                return false
            end
            fix_v = 1
        end
    end
    return true
end

"""
    still_feasible(com::CoM, constraint::Constraint, fct::MOI.VectorOfVariables, set::EqualSet, value::Int, index::Int)

Return whether the constraint can be still fulfilled.
"""
function still_feasible(
    com::CoM,
    constraint::Constraint,
    fct::MOI.VectorOfVariables,
    set::EqualSet,
    value::Int,
    index::Int,
)
    indices = filter(i -> i != index, constraint.indices)
    return all(v -> issetto(v, value) || !isfixed(v), com.search_space[indices])
end

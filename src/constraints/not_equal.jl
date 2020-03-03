"""
    Base.:!(bc::CS.BasicConstraint)

Change the `BasicConstraint` to describe the opposite of it. Only works with a `equal` basic constraint and two indices. \n
Can be used i.e by `add_constraint!(com, x != y)`.
"""
function Base.:!(bc::CS.BasicConstraint)
    if !isa(bc.set, EqualSet)
        throw(ErrorException("!BasicConstraint is only implemented for !equal"))
    end
    if length(bc.indices) != 2
        throw(ErrorException("!BasicConstraint is only implemented for !equal with exactly 2 variables"))
    end
    bc.fct, T = linear_combination_to_saf(LinearCombination(bc.indices, [1,-1]))
    bc.set = NotEqualSet{T}(zero(T))
    return bc
end

"""
    prune_constraint!(com::CS.CoM, constraint::BasicConstraint, fct::SAF{T}, set::NotEqualSet{T}; logs = true) where T <: Real

Reduce the number of possibilities given the not equal constraint and two variable which are not allowed to have the same value.
Return a ConstraintOutput object and throws a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(com::CS.CoM, constraint::BasicConstraint, fct::SAF{T}, set::NotEqualSet{T}; logs = true) where T <: Real
    indices = constraint.indices

    search_space = com.search_space
    # we always have only two variables
    v1 = search_space[indices[1]]
    v2 = search_space[indices[2]]
    fixed_v1 = isfixed(v1)
    fixed_v2 = isfixed(v2)
    if !fixed_v1 && !fixed_v2
        return true
    elseif fixed_v1 && fixed_v2
        if CS.value(v1) == CS.value(v2)
            logs && @warn "The problem is infeasible"
            return false
        end
        return true
    end
    # one is fixed and one isn't
    if fixed_v1
        prune_v = v2
        prune_v_idx = 2
        other_val = CS.value(v1)
    else
        prune_v = v1
        prune_v_idx = 1
        other_val = CS.value(v2)
    end
    if has(prune_v, other_val)
        if !rm!(com, prune_v, other_val)
            logs && @warn "The problem is infeasible"
            return false
        end
    end
    return true
end

"""
still_feasible(com::CoM, constraint::Constraint, fct::MOI.ScalarAffineFunction{T}, set::NotEqualSet{T}, value::Int, index::Int) where T <: Real

Return whether the `not_equal` constraint can be still fulfilled.
"""
function still_feasible(com::CoM, constraint::Constraint, fct::SAF{T}, set::NotEqualSet{T}, value::Int, index::Int) where T <: Real
    if index == constraint.indices[1]
        other_var = com.search_space[constraint.indices[2]]
    else
        other_var = com.search_space[constraint.indices[1]]
    end
    return !issetto(other_var, value)
end

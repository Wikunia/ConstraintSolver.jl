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
    bc.fct, T = linear_combination_to_saf(LinearCombination(bc.indices, [1, -1]))
    bc.set = NotEqualSet{T}(zero(T))
    return bc
end


function prune_not_equal_with_two_variable!(
    com::CS.CoM,
    constraint::BasicConstraint,
    fct::SAF{T},
    set::NotEqualSet{T};
    logs = true,
) where {T<:Real}
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
    prune_constraint!(com::CS.CoM, constraint::BasicConstraint, fct::SAF{T}, set::NotEqualSet{T}; logs = true) where T <: Real

Reduce the number of possibilities given the not equal constraint.
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::BasicConstraint,
    fct::SAF{T},
    set::NotEqualSet{T};
    logs = true,
) where {T<:Real}
    indices = constraint.indices
    if length(indices) == 2 && set.value == zero(T) && fct.constant == zero(T)
        return prune_not_equal_with_two_variable!(com, constraint, fct, set; logs = logs)        
    end

    # check if only one variable is variable
    nfixed = count(v -> isfixed(v), com.search_space[constraint.indices])
    if nfixed == length(constraint.indices)-1
        search_space = com.search_space
        sum = -set.value+fct.constant
        unfixed_i = 0
        for (i, idx) in enumerate(indices)
            if isfixed(search_space[idx])
                sum += CS.value(search_space[idx]) * fct.terms[i].coefficient
            else 
                unfixed_i = i
            end
        end
        @assert unfixed_i != 0
        not_val = -sum
        not_val /= fct.terms[unfixed_i].coefficient
        # if not integer
        if !isapprox_discrete(com, not_val)
            return true
        end
        not_val = get_approx_discrete(not_val)
        # if can be removed => is removed and is feasible otherwise not feasible
        if has(search_space[indices[unfixed_i]], not_val)
            return rm!(com, search_space[indices[unfixed_i]], not_val)
        else
            return true
        end
    end
    return true
end

"""
still_feasible(com::CoM, constraint::Constraint, fct::MOI.ScalarAffineFunction{T}, set::NotEqualSet{T}, value::Int, index::Int) where T <: Real

Return whether the `not_equal` constraint can be still fulfilled.
"""
function still_feasible(
    com::CoM,
    constraint::Constraint,
    fct::SAF{T},
    set::NotEqualSet{T},
    value::Int,
    index::Int,
) where {T<:Real}
    if length(constraint.indices) == 2 && set.value == zero(T) && fct.constant == zero(T)
        if index == constraint.indices[1]
            other_var = com.search_space[constraint.indices[2]]
        else
            other_var = com.search_space[constraint.indices[1]]
        end
        return !issetto(other_var, value)
    end
    # more than two variables
    indices = constraint.indices
    # check if only one variable is variable
    nfixed = count(v -> isfixed(v), com.search_space[indices])
    if nfixed >= length(indices)-1
        search_space = com.search_space
        sum = -set.value+fct.constant
        unfixed_i = 0
        for (i, idx) in enumerate(indices)
            if isfixed(search_space[idx])
                sum += CS.value(search_space[idx]) * fct.terms[i].coefficient
            elseif index == idx
                sum += value * fct.terms[i].coefficient
            else
                unfixed_i = i
            end
        end
        # all fixed => must be != 0
        if unfixed_i == 0
            # not discrete => not 0 => feasible
            if !isapprox_discrete(com, sum)
                return true
            end
            return get_approx_discrete(sum) != zero(T)
        end
        # if not fixed there is a value which fulfills the != constraint
        return true
    end
    return true
end

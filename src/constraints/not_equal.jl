"""
    Base.:!(bc::CS.LinearConstraint)

Change the `LinearConstraint` to describe the opposite of it.
Can be used i.e by `add_constraint!(com, x + y != z)`.
"""
function Base.:!(lc::CS.LinearConstraint)
    if !isa(lc.std.set, MOI.EqualTo)
        throw(ErrorException("!BasicConstraint is only implemented for !equal"))
    end
    lc.std.set = NotEqualTo{typeof(lc.std.set.value)}(lc.std.set.value)
    return lc
end

"""
    Base.:!(bc::CS.BasicConstraint)

Change the `EqualConstraint` to describe the opposite of it.
Can be used i.e by `add_constraint!(com, x != z)`.
"""
function Base.:!(ec::CS.EqualConstraint)
    if !isa(ec.std.set, EqualSetInternal)
        throw(ErrorException("!EqualConstraint is only implemented for !equal"))
    end
    if length(ec.std.indices) != 2
        throw(ErrorException("!EqualConstraint is only implemented for !equal with exactly 2 variables"))
    end
    
    func, T = linear_combination_to_saf(LinearCombination(ec.std.indices, [1, -1]))
    indices = [v.variable_index.value for v in func.terms]
    lc = LinearConstraint(func, CS.NotEqualTo(0), indices)
    lc.std.idx = ec.std.idx
    return lc
end

"""
    prune_constraint!(com::CS.CoM, constraint::BasicConstraint, fct::SAF{T}, set::NotEqualTo{T}; logs = true) where T <: Real

Reduce the number of possibilities given the not equal constraint.
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::NotEqualTo{T};
    logs = true,
) where {T<:Real}
    indices = constraint.std.indices

    # check if only one variable is variable
    nfixed = count(v -> isfixed(v), com.search_space[constraint.std.indices])
    if nfixed >= length(constraint.std.indices)-1
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
        # all fixed
        if unfixed_i == 0
            return get_approx_discrete(sum) != zero(T)
        end
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
still_feasible(com::CoM, constraint::LinearConstraint, fct::MOI.ScalarAffineFunction{T}, set::NotEqualTo{T}, value::Int, index::Int) where T <: Real

Return whether the `not_equal` constraint can be still fulfilled.
"""
function still_feasible(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::NotEqualTo{T},
    value::Int,
    index::Int,
) where {T<:Real}
    indices = constraint.std.indices
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

function is_solved_constraint(com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::NotEqualTo{T},
) where {T<:Real}

    indices = [t.variable_index.value for t in fct.terms]
    coeffs = [t.coefficient for t in fct.terms]
    values = CS.value.(com.search_space[indices])
    return get_approx_discrete(sum(values .* coeffs)+fct.constant) != set.value
end
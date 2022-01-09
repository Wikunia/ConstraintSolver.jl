"""
    prune_constraint!(com::CS.CoM, constraint::BasicConstraint, fct::SAF{T}, set::CPE.DifferentFrom{T}; logs = true) where T <: Real

Reduce the number of possibilities given the not equal constraint.
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::CPE.DifferentFrom{T};
    logs = true,
) where {T<:Real}
    indices = constraint.indices

    # check if only one variable is variable
    nfixed = count(v -> isfixed(v), com.search_space[constraint.indices])
    if nfixed >= length(constraint.indices) - 1
        search_space = com.search_space
        sum = -set.value + fct.constant
        unfixed_i = 0
        for (i, vidx) in enumerate(indices)
            if isfixed(search_space[vidx])
                sum += CS.value(search_space[vidx]) * fct.terms[i].coefficient
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
still_feasible(com::CoM, constraint::LinearConstraint, fct::MOI.ScalarAffineFunction{T}, set::CPE.DifferentFrom{T}, vidx::Int, value::Int) where T <: Real

Return whether the `not_equal` constraint can be still fulfilled.
"""
function still_feasible(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::CPE.DifferentFrom{T},
    vidx::Int,
    value::Int,
) where {T<:Real}
    indices = constraint.indices
    # check if only one variable is variable
    nfixed = count(v -> isfixed(v), com.search_space[indices])
    if nfixed >= length(indices) - 1
        search_space = com.search_space
        sum = -set.value + fct.constant
        unfixed_i = 0
        for (i, cvidx) in enumerate(indices)
            if isfixed(search_space[cvidx])
                sum += CS.value(search_space[cvidx]) * fct.terms[i].coefficient
            elseif vidx == cvidx
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

function is_constraint_solved(
    constraint::LinearConstraint,
    fct::SAF{T},
    set::CPE.DifferentFrom{T},
    values::Vector{Int},
) where {T<:Real}

    indices = [t.variable_index.value for t in fct.terms]
    coeffs = [t.coefficient for t in fct.terms]
    return get_approx_discrete(sum(values .* coeffs) + fct.constant) != set.value
end

"""
    is_constraint_violated(
        com::CoM,
        constraint::LinearConstraint,
        fct::SAF{T},
        set::CPE.DifferentFrom{T},
    ) where {T<:Real}

Checks if the constraint is violated as it is currently set. This can happen inside an
inactive reified or indicator constraint.
"""
function is_constraint_violated(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::CPE.DifferentFrom{T},
) where {T<:Real}
    if all(isfixed(var) for var in com.search_space[constraint.indices])
        return !is_constraint_solved(
            constraint,
            fct,
            set,
            [CS.value(var) for var in com.search_space[constraint.indices]],
        )
    end
    return false
end

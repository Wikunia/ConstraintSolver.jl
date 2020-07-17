"""
    prune_constraint!(com::CS.CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.LessThan{T}; logs = true) where T <: Real

Reduce the number of possibilities given the less than `LinearConstraint`.
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T};
    logs = true,
) where {T<:Real}
    indices = constraint.indices
    search_space = com.search_space
    rhs = set.upper - fct.constant

    # compute max and min values for each index
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins
    for (i, idx) in enumerate(indices)
        if fct.terms[i].coefficient >= 0
            max_val = search_space[idx].max * fct.terms[i].coefficient
            min_val = search_space[idx].min * fct.terms[i].coefficient
        else
            min_val = search_space[idx].max * fct.terms[i].coefficient
            max_val = search_space[idx].min * fct.terms[i].coefficient
        end
        maxs[i] = max_val
        mins[i] = min_val
        pre_maxs[i] = max_val
        pre_mins[i] = min_val
    end

    # for each index compute the minimum value possible
    # to fulfill the constraint
    full_min = sum(mins) - rhs

    # if the minimum is bigger than 0 (and not even near zero)
    # the equation can't sum to <= 0 => infeasible
    if full_min > com.options.atol
        com.bt_infeasible[indices] .+= 1
        return false
    end

    for (i, idx) in enumerate(indices)
        if isfixed(search_space[idx])
            continue
        end
        # minimum without current index
        c_min = full_min - mins[i]
        # if the current maximum is too high set a new maximum value to be less than 0
        if c_min + maxs[i] > com.options.atol
            maxs[i] = -c_min
        end
    end

    # update all
    for (i, idx) in enumerate(indices)
        # if the maximum of coefficient * variable got reduced
        # get a safe threshold because of floating point errors
        if maxs[i] < pre_maxs[i]
            if fct.terms[i].coefficient > 0
                threshold = get_safe_upper_threshold(com, maxs[i], fct.terms[i].coefficient)
                still_feasible = remove_above!(com, search_space[idx], threshold)
            else
                threshold = get_safe_lower_threshold(com, maxs[i], fct.terms[i].coefficient)
                still_feasible = remove_below!(com, search_space[idx], threshold)
            end
            if !still_feasible
                return false
            end
        end
    end

    return true
end

"""
    still_feasible(com::CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.LessThan{T}, val::Int, index::Int) where T <: Real

Return whether setting `search_space[index]` to `val` is still feasible given `constraint`.
"""
function still_feasible(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T},
    val::Int,
    index::Int,
) where {T<:Real}
    search_space = com.search_space
    rhs = set.upper - fct.constant
    min_sum = zero(T)

    for (i, idx) in enumerate(constraint.indices)
        if idx == index
            min_sum += val * fct.terms[i].coefficient
            continue
        end
        if isfixed(search_space[idx])
            min_sum += CS.value(search_space[idx]) * fct.terms[i].coefficient
        else
            if fct.terms[i].coefficient >= 0
                min_sum += search_space[idx].min * fct.terms[i].coefficient
            else
                min_sum += search_space[idx].max * fct.terms[i].coefficient
            end
        end
    end
    if min_sum > rhs + com.options.atol
        return false
    end

    return true
end

function is_solved_constraint(
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T},
    values::Vector{Int}
) where {T<:Real}

    indices = [t.variable_index.value for t in fct.terms]
    coeffs = [t.coefficient for t in fct.terms]
    return sum(values .* coeffs)+fct.constant <= set.upper+1e-6
end

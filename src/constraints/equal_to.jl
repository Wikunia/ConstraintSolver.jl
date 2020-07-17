"""
    get_new_extrema_and_sum(search_space, idx, i, terms, full_min, full_max, pre_mins, pre_maxs)

Get the updated full_min, full_max as well as updated pre_mins[i] and pre_maxs[i] after values got removed from search_space[idx]
Return full_min, full_max, pre_mins[i], pre_maxs[i]
"""
function get_new_extrema_and_sum(search_space, idx, i, terms, full_min, full_max, pre_mins, pre_maxs)
    new_min = pre_mins[i]
    new_max = pre_maxs[i]
    if terms[i].coefficient > 0
        coeff_min = search_space[idx].min * terms[i].coefficient
        coeff_max = search_space[idx].max * terms[i].coefficient
        full_max -= (coeff_max - pre_maxs[i])
        full_min += (coeff_min - pre_mins[i])
        new_min = coeff_min
        new_max = coeff_max
    else
        coeff_min = search_space[idx].max * terms[i].coefficient
        coeff_max = search_space[idx].min * terms[i].coefficient
        full_max -= (coeff_max - pre_maxs[i])
        full_min += (coeff_min - pre_mins[i])
        new_min = coeff_min
        new_max = coeff_max
    end
    return full_min, full_max, new_min, new_max
end

"""
    prune_constraint!(com::CS.CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.EqualTo{T}; logs = true) where T <: Real

Reduce the number of possibilities given the equality `LinearConstraint` .
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.EqualTo{T};
    logs = true,
) where {T<:Real}
    indices = constraint.indices
    search_space = com.search_space
    rhs = set.value - fct.constant

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

    # for each index compute the maximum and minimum value possible
    # to fulfill the constraint
    full_max = sum(maxs) - rhs
    full_min = sum(mins) - rhs

    # if the maximum is smaller than 0 (and not even near zero)
    # or if the minimum is bigger than 0 (and not even near zero)
    # the equation can't sum to 0 => infeasible
    if full_max < -com.options.atol || full_min > com.options.atol
        com.bt_infeasible[indices] .+= 1
        return false
    end

    changed = true
    while changed
        changed = false
        for (i, idx) in enumerate(indices)
            if isfixed(search_space[idx])
                continue
            end
            # minimum without current index
            c_min = full_min - mins[i]

            # maximum without current index
            c_max = full_max - maxs[i]

            p_max = -c_min
            if p_max < maxs[i]
                maxs[i] = p_max
            end

            p_min = -c_max
            if p_min > mins[i]
                mins[i] = p_min
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
                full_min, full_max, new_min, new_max = get_new_extrema_and_sum(search_space, idx, i, fct.terms, full_min, full_max, pre_mins, pre_maxs)
                if new_min != pre_mins[i]
                    changed = true
                    pre_mins[i] = new_min
                end
                if new_max != pre_maxs[i]
                    changed = true
                    pre_maxs[i] = new_max
                end
                mins[i] = pre_mins[i]
                maxs[i] = pre_maxs[i]
                if !still_feasible
                    return false
                end
            end
            # same if a better minimum value could be achieved
            if mins[i] > pre_mins[i]
                new_min = pre_mins[i]
                new_max = pre_maxs[i]
                if fct.terms[i].coefficient > 0
                    threshold = get_safe_lower_threshold(com, mins[i], fct.terms[i].coefficient)
                    still_feasible = remove_below!(com, search_space[idx], threshold)
                else
                    threshold = get_safe_upper_threshold(com, mins[i], fct.terms[i].coefficient)
                    still_feasible = remove_above!(com, search_space[idx], threshold)
                end
                full_min, full_max, new_min, new_max = get_new_extrema_and_sum(search_space, idx, i, fct.terms, full_min, full_max, pre_mins, pre_maxs)
                if new_min != pre_mins[i]
                    changed = true
                    pre_mins[i] = new_min
                end
                if new_max != pre_maxs[i]
                    changed = true
                    pre_maxs[i] = new_max
                end
                mins[i] = pre_mins[i]
                maxs[i] = pre_maxs[i]
                if !still_feasible
                    return false
                end
            end
        end
    end

    # if there are at most two unfixed variables left check all options
    n_unfixed = 0
    unfixed_ind_1, unfixed_ind_2 = 0, 0
    unfixed_local_ind_1, unfixed_local_ind_2 = 0, 0
    unfixed_rhs = rhs
    li = 0
    for i in indices
        li += 1
        if !isfixed(search_space[i])
            n_unfixed += 1
            if n_unfixed <= 2
                if n_unfixed == 1
                    unfixed_ind_1 = i
                    unfixed_local_ind_1 = li
                else
                    unfixed_ind_2 = i
                    unfixed_local_ind_2 = li
                end
            end
        else
            unfixed_rhs -= CS.value(search_space[i]) * fct.terms[li].coefficient
        end
    end

    # only a single one left
    if n_unfixed == 1
        if !isapprox_discrete(com, unfixed_rhs / fct.terms[unfixed_local_ind_1].coefficient)
            com.bt_infeasible[unfixed_ind_1] += 1
            return false
        else
            # divide rhs such that it is comparable with the variable directly without coefficient
            unfixed_rhs = get_approx_discrete(
                unfixed_rhs / fct.terms[unfixed_local_ind_1].coefficient,
            )
        end
        if !has(search_space[unfixed_ind_1], unfixed_rhs)
            com.bt_infeasible[unfixed_ind_1] += 1
            return false
        else
            still_feasible = fix!(com, search_space[unfixed_ind_1], unfixed_rhs)
            if !still_feasible
                return false
            end
        end
    elseif n_unfixed == 2
        is_all_different = constraint.in_all_different
        if !is_all_different
            intersect_cons =
                intersect(com.subscription[unfixed_ind_1], com.subscription[unfixed_ind_2])
            for constraint_idx in intersect_cons
                if isa(com.constraints[constraint_idx].set, AllDifferentSetInternal)
                    is_all_different = true
                    break
                end
            end
        end

        for v = 1:2
            if v == 1
                this, local_this = unfixed_ind_1, unfixed_local_ind_1
                other, local_other = unfixed_ind_2, unfixed_local_ind_2
            else
                other, local_other = unfixed_ind_1, unfixed_local_ind_1
                this, local_this = unfixed_ind_2, unfixed_local_ind_2
            end

            for val in values(search_space[this])
                # if we choose this value but the other wouldn't be an integer => remove this value
                if !isapprox_divisible(
                    com,
                    (unfixed_rhs - val * fct.terms[local_this].coefficient),
                    fct.terms[local_other].coefficient,
                )
                    if !rm!(com, search_space[this], val)
                        return false
                    end
                    continue
                end

                # get discrete other value
                check_other_val_float =
                    (unfixed_rhs - val * fct.terms[local_this].coefficient) /
                    fct.terms[local_other].coefficient
                check_other_val = get_approx_discrete(check_other_val_float)

                # if all different but those two are the same
                if is_all_different && check_other_val == val
                    if !rm!(com, search_space[this], val)
                        return false
                    end
                    if has(search_space[other], check_other_val)
                        if !rm!(com, search_space[other], check_other_val)
                            return false
                        end
                    end
                else
                    if !has(search_space[other], check_other_val)
                        if !rm!(com, search_space[this], val)
                            return false
                        end
                    end
                end
            end
        end
    end

    return true
end

"""
    still_feasible(com::CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.EqualTo{T}, val::Int, index::Int) where T <: Real

Return whether setting `search_space[index]` to `val` is still feasible given `constraint`.
"""
function still_feasible(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.EqualTo{T},
    val::Int,
    index::Int,
) where {T<:Real}
    search_space = com.search_space
    rhs = set.value - fct.constant
    csum = 0
    num_not_fixed = 0
    not_fixed_idx = 0
    not_fixed_i = 0
    max_extra = 0
    min_extra = 0
    for (i, idx) in enumerate(constraint.indices)
        if idx == index
            csum += val * fct.terms[i].coefficient
            continue
        end
        if isfixed(search_space[idx])
            csum += CS.value(search_space[idx]) * fct.terms[i].coefficient
        else
            num_not_fixed += 1
            not_fixed_idx = idx
            not_fixed_i = i
            if fct.terms[i].coefficient >= 0
                max_extra += search_space[idx].max * fct.terms[i].coefficient
                min_extra += search_space[idx].min * fct.terms[i].coefficient
            else
                min_extra += search_space[idx].max * fct.terms[i].coefficient
                max_extra += search_space[idx].min * fct.terms[i].coefficient
            end
        end
    end
    if num_not_fixed == 0 &&
       !isapprox(csum, rhs; atol = com.options.atol, rtol = com.options.rtol)
        return false
    end
    if num_not_fixed == 1 
        if isapprox_divisible(com, rhs-csum, fct.terms[not_fixed_i].coefficient)
            return has(search_space[not_fixed_idx], get_approx_discrete((rhs-csum)/fct.terms[not_fixed_i].coefficient))
        else
            return false
        end
    end

    if csum + min_extra > rhs + com.options.atol
        return false
    end

    if csum + max_extra < rhs - com.options.atol
        return false
    end

    return true
end

function is_solved_constraint(
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.EqualTo{T},
    values::Vector{Int}
) where {T<:Real}

    indices = [t.variable_index.value for t in fct.terms]
    coeffs = [t.coefficient for t in fct.terms]
    return sum(values .* coeffs)+fct.constant ≈ set.value
end
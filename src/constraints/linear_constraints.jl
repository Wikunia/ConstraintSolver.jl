"""
    init_constraint!(com::CS.CoM, constraint::CS.LinearConstraint,fct::SAF{T}, set::MOI.EqualTo{T};
                     active = true)

Initialize the LinearConstraint by checking whether it might be an unfillable constraint
without variable i.e x == x-1 => x -x == -1 => 0 == -1 => return false
"""
function init_constraint!(
    com::CS.CoM,
    constraint::CS.LinearConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T};
    active = true,
) where {T<:Real}
    constraint.rhs = set.upper - fct.constant
    length(constraint.indices) > 0 && return true

    return fct.constant <= set.upper + com.options.atol
end

function init_constraint!(
    com::CS.CoM,
    constraint::CS.LinearConstraint,
    fct::SAF{T},
    set::Union{MOI.LessThan{T},MOI.EqualTo{T}};
    active = true,
) where {T<:Real}
    constraint.rhs = set.value - fct.constant
    length(constraint.indices) > 0 && return true

    return fct.constant == set.value
end

"""
    get_new_extrema_and_sum(search_space, vidx, i, terms, full_min, full_max, pre_mins, pre_maxs)

Get the updated full_min, full_max as well as updated pre_mins[i] and pre_maxs[i]
after values got removed from search_space[vidx]
Return full_min, full_max, pre_mins[i], pre_maxs[i]
"""
function get_new_extrema_and_sum(
    search_space,
    vidx,
    i,
    terms,
    full_min,
    full_max,
    pre_mins,
    pre_maxs,
)
    new_min = pre_mins[i]
    new_max = pre_maxs[i]
    if terms[i].coefficient > 0
        coeff_min = search_space[vidx].min * terms[i].coefficient
        coeff_max = search_space[vidx].max * terms[i].coefficient
        full_max -= (coeff_max - pre_maxs[i])
        full_min += (coeff_min - pre_mins[i])
        new_min = coeff_min
        new_max = coeff_max
    else
        coeff_min = search_space[vidx].max * terms[i].coefficient
        coeff_max = search_space[vidx].min * terms[i].coefficient
        full_max -= (coeff_max - pre_maxs[i])
        full_min += (coeff_min - pre_mins[i])
        new_min = coeff_min
        new_max = coeff_max
    end
    return full_min, full_max, new_min, new_max
end

"""
    get_fixed_rhs(com::CS.CoM, constraint::Constraint)

Compute the fixed rhs based on all already fixed variables
"""
function get_fixed_rhs(com::CS.CoM, constraint::Constraint)
    rhs = constraint.rhs
    fct = constraint.fct
    search_space = com.search_space
    for li in 1:length(constraint.indices)
        vidx = constraint.indices[li]
        var = search_space[vidx]
        !isfixed(var) && continue
        rhs -= CS.value(var) * fct.terms[li].coefficient
    end
    return rhs
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
    set::Union{MOI.LessThan{T},MOI.EqualTo{T}};
    logs = true,
) where {T<:Real}
    indices = constraint.indices
    search_space = com.search_space
    rhs = constraint.rhs

    # compute max and min values for each index
    recompute_lc_extrema!(com, constraint, fct)
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins

    # for each index compute the maximum and minimum value possible
    # to fulfill the constraint
    full_max = sum(maxs) - rhs
    full_min = sum(mins) - rhs

    # if the maximum is smaller than 0 (and not even near zero)
    # or if the minimum is bigger than 0 (and not even near zero)
    # the equation can't sum to 0 => infeasible
    if full_min > com.options.atol
        com.bt_infeasible[indices] .+= 1
        return false
    end
    if full_max < -com.options.atol && constraint.is_equal
        com.bt_infeasible[indices] .+= 1
        return false
    end

    changed = true
    while changed
        changed = false
        for (i, vidx) in enumerate(indices)
            if isfixed(search_space[vidx])
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

            if constraint.is_equal
                p_min = -c_max
                if p_min > mins[i]
                    mins[i] = p_min
                end
            end
        end

        # update all
        for (i, vidx) in enumerate(indices)
            # if the maximum of coefficient * variable got reduced
            # get a safe threshold because of floating point errors
            if maxs[i] < pre_maxs[i]
                if fct.terms[i].coefficient > 0
                    threshold =
                        get_safe_upper_threshold(com, maxs[i], fct.terms[i].coefficient)
                    still_feasible = remove_above!(com, search_space[vidx], threshold)
                else
                    threshold =
                        get_safe_lower_threshold(com, maxs[i], fct.terms[i].coefficient)
                    still_feasible = remove_below!(com, search_space[vidx], threshold)
                end
                full_min, full_max, new_min, new_max = get_new_extrema_and_sum(
                    search_space,
                    vidx,
                    i,
                    fct.terms,
                    full_min,
                    full_max,
                    pre_mins,
                    pre_maxs,
                )
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
                    threshold =
                        get_safe_lower_threshold(com, mins[i], fct.terms[i].coefficient)
                    still_feasible = remove_below!(com, search_space[vidx], threshold)
                else
                    threshold =
                        get_safe_upper_threshold(com, mins[i], fct.terms[i].coefficient)
                    still_feasible = remove_above!(com, search_space[vidx], threshold)
                end
                full_min, full_max, new_min, new_max = get_new_extrema_and_sum(
                    search_space,
                    vidx,
                    i,
                    fct.terms,
                    full_min,
                    full_max,
                    pre_mins,
                    pre_maxs,
                )
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

    # the following is only for an equal constraint
    !constraint.is_equal && return true
    n_unfixed = count_unfixed(com, constraint)
    n_unfixed != 2 && return true

    fixed_rhs = get_fixed_rhs(com, constraint)

    local_vidx_1, vidx_1, local_vidx_2, vidx_2 = get_two_unfixed(com, constraint)
    for ((this_local_vidx, this_vidx), (other_local_vidx, other_vidx)) in zip(
        ((local_vidx_1, vidx_1), (local_vidx_2, vidx_2)),
        ((local_vidx_2, vidx_2), (local_vidx_1, vidx_1))
    )
        this_var = search_space[this_vidx]
        other_var = search_space[other_vidx]
        for val in values(this_var)
            # if we choose this value but the other wouldn't be an integer => remove this value
            if !isapprox_divisible(
                com,
                (fixed_rhs - val * fct.terms[this_local_vidx].coefficient),
                fct.terms[other_local_vidx].coefficient,
            )
                if !rm!(com, this_var, val)
                    return false
                end
                continue
            end

            remainder = fixed_rhs - val * fct.terms[this_local_vidx].coefficient
            remainder /= fct.terms[other_local_vidx].coefficient
            remainder_int = get_approx_discrete(remainder)
            if !has(other_var, remainder_int)
                !rm!(com, this_var, val) && return false
            end
        end
    end

    # if only one is unfixed => fix it
    var_1 = search_space[vidx_1]
    var_2 = search_space[vidx_2]
    if isfixed(var_1) || isfixed(var_2)
        if isfixed(var_1)
            unfixed_var = var_2
            unfixed_local_idx = local_vidx_2
            fixed_local_idx = local_vidx_1
        else
            unfixed_var = var_1
            unfixed_local_idx = local_vidx_1
            fixed_local_idx = local_vidx_2
        end
        fixed_coeff = fct.terms[fixed_local_idx].coefficient
        unfixed_coeff = fct.terms[unfixed_local_idx].coefficient
        if isfixed(var_1)
            fixed_rhs -= fixed_coeff*value(var_1)
        else
            fixed_rhs -= fixed_coeff*value(var_2)
        end
        !isapprox_divisible(com, fixed_rhs, unfixed_coeff) && return false
        remainder = fixed_rhs
        remainder /= unfixed_coeff
        remainder_int = get_approx_discrete(remainder)
        !has(unfixed_var, remainder_int) && return false
        !fix!(com, unfixed_var, remainder_int) && return false
    end

    #=
    if n_unfixed == 1
        for li in 1:length(constraint.indices)
            var = search_space[li]
            isfixed(var) && continue
            !isapprox_divisible(com, rhs, fct.terms[li].coefficient) && return false
            remainder = rhs
            remainder /= fct.terms[li].coefficient
            remainder_int = get_approx_discrete(remainder)
            !fix!(com, var, remainder_int) && return false
        end
    end
    =#

    return true
end

"""
    still_feasible(com::CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.EqualTo{T}, vidx::Int, val::Int) where T <: Real

Return whether setting `search_space[vidx]` to `val` is still feasible given `constraint`.
"""
function still_feasible(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::Union{MOI.LessThan{T},MOI.EqualTo{T}},
    vidx::Int,
    val::Int,
) where {T<:Real}
    search_space = com.search_space
    rhs = constraint.rhs
    csum = 0
    num_not_fixed = 0
    not_fixed_idx = 0
    not_fixed_i = 0
    max_extra = 0
    min_extra = 0
    for (i, cvidx) in enumerate(constraint.indices)
        if cvidx == vidx
            csum += val * fct.terms[i].coefficient
            continue
        end
        if isfixed(search_space[cvidx])
            csum += CS.value(search_space[cvidx]) * fct.terms[i].coefficient
        else
            num_not_fixed += 1
            not_fixed_idx = cvidx
            not_fixed_i = i
            if fct.terms[i].coefficient >= 0
                max_extra += search_space[cvidx].max * fct.terms[i].coefficient
                min_extra += search_space[cvidx].min * fct.terms[i].coefficient
            else
                min_extra += search_space[cvidx].max * fct.terms[i].coefficient
                max_extra += search_space[cvidx].min * fct.terms[i].coefficient
            end
        end
    end
    if num_not_fixed == 0
        if constraint.is_equal
            return isapprox(csum, rhs; atol = com.options.atol, rtol = com.options.rtol)
        else
            return csum <= rhs
        end
    end
    if num_not_fixed == 1 && constraint.is_equal
        if isapprox_divisible(com, rhs - csum, fct.terms[not_fixed_i].coefficient)
            return has(
                search_space[not_fixed_idx],
                get_approx_discrete((rhs - csum) / fct.terms[not_fixed_i].coefficient),
            )
        else
            return false
        end
    end

    if csum + min_extra > rhs + com.options.atol
        return false
    end

    if constraint.is_equal && csum + max_extra < rhs - com.options.atol
        return false
    end

    return true
end

function is_constraint_solved(
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.EqualTo{T},
    values::Vector{Int},
) where {T<:Real}

    indices = [t.variable_index.value for t in fct.terms]
    coeffs = [t.coefficient for t in fct.terms]
    return sum(values .* coeffs) + fct.constant ≈ set.value
end

function is_constraint_solved(
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T},
    values::Vector{Int},
) where {T<:Real}

    indices = [t.variable_index.value for t in fct.terms]
    coeffs = [t.coefficient for t in fct.terms]
    return sum(values .* coeffs) + fct.constant <= set.upper + 1e-6
end


"""
    is_constraint_violated(
        com::CoM,
        constraint::LinearConstraint,
        fct::SAF{T},
        set::MOI.EqualTo{T}
    ) where {T<:Real}

Checks if the constraint is violated as it is currently set. This can happen inside an
inactive reified or indicator constraint.
"""
function is_constraint_violated(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::Union{MOI.LessThan{T},MOI.EqualTo{T}},
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

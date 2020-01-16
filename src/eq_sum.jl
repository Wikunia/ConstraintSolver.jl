"""
    Base.:(==)(x::LinearCombination, y::Real)

Create a linear constraint with `LinearCombination` and an integer rhs `y`. \n
Can be used i.e by `add_constraint!(com, x+y = 2)`.
"""
function Base.:(==)(x::LinearCombination, y::Real)
    indices, coeffs, constant_lhs = simplify(x)
    
    rhs = y-constant_lhs
    func, T = linear_combination_to_saf(LinearCombination(indices, coeffs))
    lc = LinearConstraint(func, MOI.EqualTo{T}(rhs), indices)
    
    lc.hash = constraint_hash(lc)
    return lc
end

"""
    Base.:(==)(x::LinearCombination, y::Variable)

Create a linear constraint with `LinearCombination` and a variable rhs `y`. \n
Can be used i.e by `add_constraint!(com, x+y = z)`.
"""
function Base.:(==)(x::LinearCombination, y::Variable)
    return x == LinearCombination([y.idx], [1])
end

"""
    Base.:(==)(x::LinearCombination, y::LinearCombination)

Create a linear constraint with `LinearCombination` on the left and right hand side. \n
Can be used i.e by `add_constraint!(com, x+y = a+b)`.
"""
function Base.:(==)(x::LinearCombination, y::LinearCombination)
    return x-y == 0
end

function prune_constraint!(com::CS.CoM, constraint::LinearConstraint, fct::MOI.ScalarAffineFunction{T}, set::MOI.EqualTo{T}; logs = true) where T <: Real
    indices = constraint.indices
    search_space = com.search_space
    rhs = set.value - fct.constant
    # println("constraint: ", constraint)

    # compute max and min values for each index
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins
    for (i,idx) in enumerate(indices)
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
    full_max = sum(maxs)-rhs
    full_min = sum(mins)-rhs

    if full_max < 0 || full_min > 0
        com.bt_infeasible[indices] .+= 1
        return false
    end

    for (i,idx) in enumerate(indices)
        if isfixed(search_space[idx])
            continue
        end
        # minimum without current index
        c_min = full_min-mins[i]

        # maximum without current index
        c_max = full_max-maxs[i]

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
    for (i,idx) in enumerate(indices)
        if maxs[i] < pre_maxs[i]
            threshold = get_safe_upper_threshold(com, maxs[i], fct.terms[i].coefficient)
            if fct.terms[i].coefficient > 0
                still_feasible = remove_above!(com, search_space[idx], threshold)
            else
                still_feasible = remove_below!(com, search_space[idx], threshold)
            end
            if !still_feasible
                return false
            end
        end
        if mins[i] > pre_mins[i]
            threshold = get_safe_lower_threshold(com, mins[i], fct.terms[i].coefficient)
            if fct.terms[i].coefficient > 0
                still_feasible = remove_below!(com, search_space[idx], threshold)
            else
                still_feasible = remove_above!(com, search_space[idx], threshold)
            end
            if !still_feasible
                return false
            end
        end
    end

    # if there are only two left check all options
    n_unfixed = 0
    unfixed_ind_1, unfixed_ind_2 = 0, 0
    unfixed_local_ind_1, unfixed_local_ind_2 = 0,0
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
            unfixed_rhs -= CS.value(search_space[i])*fct.terms[li].coefficient
        end
    end

    # only a single one left
    if n_unfixed == 1
        if !isapprox_discrete(com, unfixed_rhs % fct.terms[unfixed_local_ind_1].coefficient)
            com.bt_infeasible[unfixed_ind_1] += 1
            return false
        else
            # divide rhs such that it is comparable with the variable directly without coefficient
            unfixed_rhs = get_approx_discrete(unfixed_rhs / fct.terms[unfixed_local_ind_1].coefficient)
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
            intersect_cons = intersect(com.subscription[unfixed_ind_1], com.subscription[unfixed_ind_2])
            for constraint_idx in intersect_cons
                if isa(com.constraints[constraint_idx].set, AllDifferentSet)
                    is_all_different = true
                    break
                end
            end
        end

        for v in 1:2
            if v == 1
                this, local_this = unfixed_ind_1, unfixed_local_ind_1
                other, local_other = unfixed_ind_2, unfixed_local_ind_2
            else
                other, local_other = unfixed_ind_1, unfixed_local_ind_1
                this, local_this = unfixed_ind_2, unfixed_local_ind_2
            end

            for val in values(search_space[this])
                # if we choose this value but the other wouldn't be an integer => remove this value
                if !isapprox_divisible(com, (unfixed_rhs-val*fct.terms[local_this].coefficient), fct.terms[local_other].coefficient)
                    if !rm!(com, search_space[this], val)
                        return false
                    end
                    continue
                end

                # get discrete other value
                check_other_val_float = (unfixed_rhs-val*fct.terms[local_this].coefficient)/fct.terms[local_other].coefficient
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

function still_feasible(com::CoM, constraint::LinearConstraint, fct::MOI.ScalarAffineFunction{T}, set::MOI.EqualTo{T}, val::Int, index::Int) where T <: Real
    search_space = com.search_space
    rhs = set.value - fct.constant
    csum = 0
    num_not_fixed = 0
    max_extra = 0
    min_extra = 0
    for (i,idx) in enumerate(constraint.indices)
        if idx == index
            val = val*fct.terms[i].coefficient
            continue
        end
        if isfixed(search_space[idx])
            csum += CS.value(search_space[idx])*fct.terms[i].coefficient
        else
            num_not_fixed += 1
            if fct.terms[i].coefficient >= 0
                max_extra += search_space[idx].max*fct.terms[i].coefficient
                min_extra += search_space[idx].min*fct.terms[i].coefficient
            else
                min_extra += search_space[idx].max*fct.terms[i].coefficient
                max_extra += search_space[idx].min*fct.terms[i].coefficient
            end
        end
    end
    if num_not_fixed == 0 && !isapprox(csum + val, rhs; atol=com.options.atol, rtol=com.options.rtol)
        return false
    end

    if csum + val + min_extra > rhs+com.options.atol
        return false
    end

    if csum + val + max_extra < rhs-com.options.atol
        return false
    end

    return true
end

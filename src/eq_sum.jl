function eq_sum(com::CS.CoM, constraint::Constraint; logs = true)
    indices = constraint.indices
    search_space = com.search_space
    changed = Dict{Int, Bool}()
    pruned  = zeros(Int, length(indices))
    pruned_below  = zeros(Int, length(indices))
    
    # compute max and min values for each index
    maxs = zeros(Int, length(indices))
    mins = zeros(Int, length(indices))
    pre_maxs = zeros(Int, length(indices))
    pre_mins = zeros(Int, length(indices))
    for (i,idx) in enumerate(indices)
        max_val = search_space[idx].max
        min_val = search_space[idx].min
        maxs[i] = max_val
        mins[i] = min_val
        pre_maxs[i] = max_val
        pre_mins[i] = min_val
    end

    # for each index compute the maximum and minimum value possible
    # to fulfill the constraint
    full_max = sum(maxs)-constraint.rhs
    full_min = sum(mins)-constraint.rhs

    for (i,idx) in enumerate(indices)
        if isfixed(search_space[idx])
            continue
        end
        # minimum without current index
        c_min = full_min-mins[i]
        # if the minimum is already too big
        if c_min > -mins[i]
            com.bt_infeasible[idx] += 1
            return ConstraintOutput(false, changed, pruned, pruned_below)
        end
        # maximum without current index
        c_max = full_max-maxs[i]
        # if the maximum is already too small
        if c_max < -maxs[i]
            com.bt_infeasible[idx] += 1
            return ConstraintOutput(false, changed, pruned, pruned_below)
        end

        if c_min < -mins[i]
            mins[i] = -c_min
        end
        if c_max > -maxs[i]
            maxs[i] = -c_max
        end
    end
    
    # update all 
    for (i,idx) in enumerate(indices)
        if maxs[i] < pre_maxs[i]
            still_feasible, nremoved = remove_below!(com, search_space[idx], maxs[i])
            if !still_feasible
                return ConstraintOutput(false, changed, pruned, pruned_below)
            end
            if nremoved > 0
                changed[idx] = true
                pruned[i] += nremoved
            end
        end
        if mins[i] > pre_mins[i]
            still_feasible, nremoved = remove_above!(com, search_space[idx], mins[i])
            if !still_feasible
                return ConstraintOutput(false, changed, pruned, pruned_below)
            end
            if nremoved > 0
                changed[idx] = true
                pruned[i] += nremoved
            end
        end
    end
    
    # if there are only two left check all options
    n_unfixed = 0
    unfixed_ind = zeros(Int,2)
    unfixed_local_ind = zeros(Int,2)
    unfixed_rhs = constraint.rhs
    li = 0
    for i in indices 
        li += 1
        if !isfixed(search_space[i])
            n_unfixed += 1
            if n_unfixed <= 2
                unfixed_ind[n_unfixed] = i
                unfixed_local_ind[n_unfixed] = li
            end
        else
            unfixed_rhs -= value(search_space[i])
        end
    end
    if n_unfixed == 1
        if !has(search_space[unfixed_ind[1]], unfixed_rhs)
            return ConstraintOutput(false, changed, pruned, pruned_below)
        else
            changed[unfixed_ind[1]] = true
            still_feasible, pr_below, pr_above = fix!(com, search_space[unfixed_ind[1]], unfixed_rhs)
            if !still_feasible
                return ConstraintOutput(false, changed, pruned, pruned_below)
            end
            pruned[unfixed_local_ind[1]] += pr_above
            pruned_below[unfixed_local_ind[1]] += pr_below
        end
    elseif n_unfixed == 2
        intersect_cons = intersect(com.subscription[unfixed_ind[1]], com.subscription[unfixed_ind[2]])
        is_all_different = false
        for constraint_idx in intersect_cons
            if nameof(com.constraints[constraint_idx].fct) == :all_different
                is_all_different = true
                break
            end
        end

        for v in 1:2
            if v == 1
                this, local_this = unfixed_ind[1], unfixed_local_ind[1]
                other, local_other = unfixed_ind[2], unfixed_local_ind[2]
            else
                other, local_other = unfixed_ind[1], unfixed_local_ind[1]
                this, local_this = unfixed_ind[2], unfixed_local_ind[2]
            end
            for val in values(search_space[this])
                if is_all_different && unfixed_rhs-val == val
                    if !rm!(com, search_space[this], val)
                        return ConstraintOutput(false, changed, pruned, pruned_below)
                    end
                    changed[this] = true
                    pruned[local_this] += 1
                    if has(search_space[other], unfixed_rhs-val)
                        if !rm!(com, search_space[other], val)
                            return ConstraintOutput(false, changed, pruned, pruned_below)
                        end
                        changed[other] = true
                        pruned[local_other] += 1
                    end
                else
                    if !has(search_space[other], unfixed_rhs-val)
                        if !rm!(com, search_space[this], val)
                            return ConstraintOutput(false, changed, pruned, pruned_below)
                        end
                        changed[this] = true
                        pruned[local_this] += 1
                    end
                end
            end
        end
    end

    return ConstraintOutput(true, changed, pruned, pruned_below)
end

function eq_sum(com::CoM, constraint::Constraint, val::Int, index::Int)
    indices = filter(i->i!=index, constraint.indices)
    search_space = com.search_space
    csum = 0
    num_not_fixed = 0
    max_extra = 0
    min_extra = 0
    for idx in indices
        if isfixed(search_space[idx])
            csum += value(search_space[idx])
        else
            num_not_fixed += 1
            max_extra += search_space[idx].max
            min_extra += search_space[idx].min
        end
    end
    if num_not_fixed == 0 && csum + val != constraint.rhs
        return false
    end

    if csum + val + min_extra > constraint.rhs
        return false
    end

    if csum + val + max_extra < constraint.rhs
        return false
    end

    return true
end
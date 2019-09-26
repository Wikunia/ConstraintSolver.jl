function eq_sum(com::CS.CoM, constraint::Constraint; logs = true)
    indices = constraint.indices
    search_space = com.search_space
    changed = Dict{Int, Bool}()
    pruned  = zeros(Int, length(indices))
    
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
            return ConstraintOutput(false, changed, pruned)
        end
        # maximum without current index
        c_max = full_max-maxs[i]
        # if the maximum is already too small
        if c_max < -maxs[i]
            com.bt_infeasible[idx] += 1
            return ConstraintOutput(false, changed, pruned)
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
            nremoved = remove_below(search_space[idx], maxs[i])
            if nremoved > 0
                changed[idx] = true
                pruned[i] += nremoved
                if !feasible(search_space[idx])
                    com.bt_infeasible[idx] += 1
                    return ConstraintOutput(false, changed, pruned)
                end
            end
        end
        if mins[i] > pre_mins[i]
            nremoved = remove_above(search_space[idx], mins[i])
            if nremoved > 0
                changed[idx] = true
                pruned[i] += nremoved
                if !feasible(search_space[idx])
                    com.bt_infeasible[idx] += 1
                    return ConstraintOutput(false, changed, pruned)
                end
            end
        end
    end

    # if there are only two left check all options
    n_open = 0
    open_ind = zeros(Int,2)
    open_local_ind = zeros(Int,2)
    open_rhs = constraint.rhs
    li = 0
    for i in indices 
        li += 1
        if !isfixed(search_space[i])
            n_open += 1
            if n_open <= 2
                open_ind[n_open] = i
                open_local_ind[n_open] = li
            end
        else
            open_rhs -= value(search_space[i])
        end
    end
    #=
    if n_open == 2
        intersect_cons = intersect(com.subscription[open_ind[1]], com.subscription[open_ind[2]])
        is_all_different = false
        for constraint_idx in intersect_cons
            if nameof(com.constraints[constraint_idx].fct) == :all_different
                is_all_different = true
                break
            end
        end

        for v in 1:2
            if v == 1
                this, local_this = open_ind[1], open_local_ind[1]
                other, local_other = open_ind[2], open_local_ind[2]
            else
                other, local_other = open_ind[1], open_local_ind[1]
                this, local_this = open_ind[2], open_local_ind[2]
            end
            for val in values(search_space[this])
                if is_all_different && open_rhs-val == val
                    rm!(search_space[this], val)
                    changed[this] = true
                    pruned[local_this] += 1
                    if has(search_space[other], open_rhs-val)
                        rm!(search_space[other], val)
                        changed[other] = true
                        pruned[local_other] += 1
                    end
                else
                    if !has(search_space[other], open_rhs-val)
                        rm!(search_space[this], val)
                        changed[this] = true
                        pruned[local_this] += 1
                    end
                end
            end
        end
    end
    =#

    return ConstraintOutput(true, changed, pruned)
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
function eq_sum(com::CS.CoM, constraint::Constraint; logs = true)
    indices = constraint.indices
    search_space = com.search_space
    changed = Dict{Int, Bool}()
    pruned  = zeros(Int, length(indices))
    #=
    println("indices: ")
    println(indices)
    println("RHS: ", constraint.rhs)
    =#

    # compute max and min values for each index
    maxs = zeros(Int, length(indices))
    mins = zeros(Int, length(indices))
    pre_maxs = zeros(Int, length(indices))
    pre_mins = zeros(Int, length(indices))
    for (i,idx) in enumerate(indices)
        maxs[i] = com.search_space[idx].max
        mins[i] = com.search_space[idx].min
        pre_maxs[i] = maxs[i]
        pre_mins[i] = mins[i]
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
            return ConstraintOutput(false, changed, pruned)
        end
        # maximum without current index
        c_max = full_max-maxs[i]
        # if the maximum is already too small
        if c_max < -maxs[i]
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
                    return ConstraintOutput(false, changed, pruned)
                end
            end
        end
    end

    return ConstraintOutput(true, changed, pruned)
end

function eq_sum(com::CoM, constraint::Constraint, val::Int; index=nothing)
    if index === nothing
        indices = constraint.indices
    else
        indices = filter(i->i!=index, constraint.indices)
    end
    csum = 0
    num_not_fixed = 0
    max_extra = 0
    min_extra = 0
    for idx in indices
        if isfixed(com.search_space[idx])
            csum += value(com.search_space[idx])
        else
            num_not_fixed += 1
            max_extra += com.search_space[idx].max
            min_extra += com.search_space[idx].min
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
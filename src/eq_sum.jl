function Base.:(==)(x::LinearVariables, y::Int)
    lc = LinearConstraint()
    lc.fct = eq_sum
    lc.indices = x.indices
    lc.coeffs = x.coeffs
    lc.operator = :(==)
    lc.rhs = y
    return lc
end


function eq_sum(com::CS.CoM, constraint::LinearConstraint; logs = true)
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
        if constraint.coeffs[i] >= 0
            max_val = search_space[idx].max * constraint.coeffs[i]
            min_val = search_space[idx].min * constraint.coeffs[i]
        else
            min_val = search_space[idx].max * constraint.coeffs[i]
            max_val = search_space[idx].min * constraint.coeffs[i]
        end
        maxs[i] = max_val
        mins[i] = min_val
        pre_maxs[i] = max_val
        pre_mins[i] = min_val
    end

    # for each index compute the maximum and minimum value possible
    # to fulfill the constraint
    full_max = sum(maxs)-constraint.rhs
    full_min = sum(mins)-constraint.rhs

    if full_max < 0 || full_min > 0
        com.bt_infeasible[indices] .+= 1
        return ConstraintOutput(false, changed, pruned, pruned_below)
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
            if constraint.coeffs[i] > 0
                still_feasible, nremoved = remove_above!(com, search_space[idx], fld(maxs[i], constraint.coeffs[i]))
            else
                still_feasible, nremoved = remove_below!(com, search_space[idx], fld(maxs[i], constraint.coeffs[i]))
            end            
            if !still_feasible
                # println("i above: ", i)
                return ConstraintOutput(false, changed, pruned, pruned_below)
            end
            if nremoved > 0
                changed[idx] = true
                pruned[i] += nremoved
            end
        end
        if mins[i] > pre_mins[i]
            if constraint.coeffs[i] > 0
                still_feasible, nremoved = remove_below!(com, search_space[idx], cld(mins[i], constraint.coeffs[i]))
            else
                still_feasible, nremoved = remove_above!(com, search_space[idx], cld(mins[i], constraint.coeffs[i]))
            end
            if !still_feasible
                # println("i below: ", i)
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
            unfixed_rhs -= value(search_space[i])*constraint.coeffs[li]
        end
    end

    # only a single one left
    if n_unfixed == 1
        if unfixed_rhs % constraint.coeffs[unfixed_local_ind[1]] != 0
            com.bt_infeasible[unfixed_ind[1]] += 1
            return ConstraintOutput(false, changed, pruned, pruned_below)
        else 
            # divide rhs such that it is comparable with the variable directly without coefficient
            unfixed_rhs = fld(unfixed_rhs, constraint.coeffs[unfixed_local_ind[1]])
        end
        if !has(search_space[unfixed_ind[1]], unfixed_rhs)
            com.bt_infeasible[unfixed_ind[1]] += 1
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
                # if we choose this value but the other wouldn't be an integer => remove this value
                if (unfixed_rhs-val*constraint.coeffs[local_this]) % constraint.coeffs[local_other] != 0
                    if !rm!(com, search_space[this], val)
                        return ConstraintOutput(false, changed, pruned, pruned_below)
                    end
                    changed[this] = true
                    pruned[local_this] += 1
                    continue
                end

                check_other_val = fld(unfixed_rhs-val*constraint.coeffs[local_this], constraint.coeffs[local_other])
                # if all different but those two are the same 
                if is_all_different && check_other_val == val
                    if !rm!(com, search_space[this], val)
                        return ConstraintOutput(false, changed, pruned, pruned_below)
                    end
                    changed[this] = true
                    pruned[local_this] += 1
                    if has(search_space[other], check_other_val)
                        if !rm!(com, search_space[other], check_other_val)
                            return ConstraintOutput(false, changed, pruned, pruned_below)
                        end
                        changed[other] = true
                        pruned[local_other] += 1
                    end
                else
                    if !has(search_space[other], check_other_val)
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

function eq_sum(com::CoM, constraint::LinearConstraint, val::Int, index::Int)
    search_space = com.search_space
    csum = 0
    num_not_fixed = 0
    max_extra = 0
    min_extra = 0
    for (i,idx) in enumerate(constraint.indices)
        if idx == index
            val = val*constraint.coeffs[i]
            continue
        end
        if isfixed(search_space[idx])
            csum += value(search_space[idx])*constraint.coeffs[i]
        else
            num_not_fixed += 1
            if constraint.coeffs[i] >= 0
                max_extra += search_space[idx].max*constraint.coeffs[i]
                min_extra += search_space[idx].min*constraint.coeffs[i]
            else
                min_extra += search_space[idx].max*constraint.coeffs[i]
                max_extra += search_space[idx].min*constraint.coeffs[i]
            end
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
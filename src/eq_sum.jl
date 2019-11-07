"""
    Base.:(==)(x::LinearVariables, y::Int)

Create a linear constraint with `LinearVariables` and an integer rhs `y`. \n
Can be used i.e by `add_constraint!(com, x+y = 2)`.
"""
function Base.:(==)(x::LinearVariables, y::Int)
    lc = LinearConstraint()
    indices, coeffs, constant_lhs = simplify(x)
    lc.fct = eq_sum
    lc.indices = indices
    lc.coeffs = coeffs
    lc.operator = :(==)
    lc.rhs = y-constant_lhs
    lc.maxs = zeros(Int, length(indices))
    lc.mins = zeros(Int, length(indices))
    lc.pre_maxs = zeros(Int, length(indices))
    lc.pre_mins = zeros(Int, length(indices))
    return lc
end

"""
    Base.:(==)(x::LinearVariables, y::Variable)

Create a linear constraint with `LinearVariables` and a variable rhs `y`. \n
Can be used i.e by `add_constraint!(com, x+y = z)`.
"""
function Base.:(==)(x::LinearVariables, y::Variable)
    return x == LinearVariables([y.idx], [1])
end

"""
    Base.:(==)(x::LinearVariables, y::LinearVariables)

Create a linear constraint with `LinearVariables` on the left and right hand side. \n
Can be used i.e by `add_constraint!(com, x+y = a+b)`.
"""
function Base.:(==)(x::LinearVariables, y::LinearVariables)
    return x-y == 0
end

function eq_sum(com::CS.CoM, constraint::LinearConstraint; logs = true)
    indices = constraint.indices
    search_space = com.search_space

    # compute max and min values for each index
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins
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
        logs && @warn "full_max: $full_max < 0 || full_min: $full_min > 0"
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
            if constraint.coeffs[i] > 0
                still_feasible = remove_above!(com, search_space[idx], fld(maxs[i], constraint.coeffs[i]))
                logs && @info "removed above $(fld(maxs[i], constraint.coeffs[i])) for idx: $idx at constraint.idx = $(constraint.idx)"
            else
                still_feasible = remove_below!(com, search_space[idx], fld(maxs[i], constraint.coeffs[i]))
                logs && @info "removed below $(fld(maxs[i], constraint.coeffs[i])) for idx: $idx at constraint.idx = $(constraint.idx)"
            end            
            if !still_feasible
                logs && @warn "maxs changed for i: $i at constraint.idx = $(constraint.idx) and got infeasible"
                return false
            end
        end
        if mins[i] > pre_mins[i]
            if constraint.coeffs[i] > 0
                still_feasible = remove_below!(com, search_space[idx], cld(mins[i], constraint.coeffs[i]))
                logs && @info "removed below $(cld(mins[i], constraint.coeffs[i])) for idx: $idx at constraint.idx = $(constraint.idx)"
            else
                still_feasible = remove_above!(com, search_space[idx], cld(mins[i], constraint.coeffs[i]))
                logs && @info "removed above $(cld(mins[i], constraint.coeffs[i])) for idx: $idx at constraint.idx = $(constraint.idx)"
            end
            if !still_feasible
                logs && @warn "mins changed for i: $i at constraint.idx = $(constraint.idx) and got infeasible"
                return false
            end
        end
    end

    # if there are only two left check all options
    n_unfixed = 0
    unfixed_ind_1, unfixed_ind_2 = 0, 0
    unfixed_local_ind_1, unfixed_local_ind_2 = 0,0
    unfixed_rhs = constraint.rhs
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
            unfixed_rhs -= value(search_space[i])*constraint.coeffs[li]
        end
    end

    # only a single one left
    if n_unfixed == 1
        if unfixed_rhs % constraint.coeffs[unfixed_local_ind_1] != 0
            com.bt_infeasible[unfixed_ind_1] += 1
            return false
        else 
            # divide rhs such that it is comparable with the variable directly without coefficient
            unfixed_rhs = fld(unfixed_rhs, constraint.coeffs[unfixed_local_ind_1])
        end
        if !has(search_space[unfixed_ind_1], unfixed_rhs)
            com.bt_infeasible[unfixed_ind_1] += 1
            logs && @warn "Only single left  and needed value not existent at constraint.idx = $(constraint.idx) and got infeasible"
            return false
        else
            still_feasible = fix!(com, search_space[unfixed_ind_1], unfixed_rhs)
            if !still_feasible
                logs && @warn "Only single left but can't fix it because others at constraint.idx = $(constraint.idx) and got infeasible"
                return false
            end
            logs && @info "fixed idx: $unfixed_ind_1 to $unfixed_rhs at constraint.idx = $(constraint.idx)"
        end
    elseif n_unfixed == 2
        is_all_different = constraint.in_all_different
        logs && @info "Only two left: Before intersect is_all_different: $is_all_different"
        if !is_all_different
            intersect_cons = intersect(com.subscription[unfixed_ind_1], com.subscription[unfixed_ind_2])
            logs && @info "$(com.subscription[unfixed_ind_1]) and $(com.subscription[unfixed_ind_2])"
            logs && @info "intersect_cons: $(intersect_cons)"
            for constraint_idx in intersect_cons
                if nameof(com.constraints[constraint_idx].fct) == :all_different
                    is_all_different = true
                    break
                end
            end
        end
        logs && @info "Only two left is_all_different: $is_all_different"
        logs && @info "Only two left : $unfixed_ind_1 and $unfixed_ind_2"

        for v in 1:2
            logs && @info "eq_sum: only two left v: $v"
            if v == 1
                this, local_this = unfixed_ind_1, unfixed_local_ind_1
                other, local_other = unfixed_ind_2, unfixed_local_ind_2
            else
                other, local_other = unfixed_ind_1, unfixed_local_ind_1
                this, local_this = unfixed_ind_2, unfixed_local_ind_2
            end
    

            for val in values(search_space[this])
                # if we choose this value but the other wouldn't be an integer => remove this value
                if (unfixed_rhs-val*constraint.coeffs[local_this]) % constraint.coeffs[local_other] != 0
                    if !rm!(com, search_space[this], val)
                        logs && @warn "Two left but can't remove a value at constraint.idx = $(constraint.idx) and got infeasible (1)"
                        return false
                    end
                    logs && @info "Two left and removed $val at idx: $this at constraint.idx = $(constraint.idx) (1)"
                    continue
                end

                check_other_val = fld(unfixed_rhs-val*constraint.coeffs[local_this], constraint.coeffs[local_other])
                # if all different but those two are the same 
                if is_all_different && check_other_val == val
                    if !rm!(com, search_space[this], val)
                        logs && @warn "Two left but can't remove a value at constraint.idx = $(constraint.idx) and got infeasible (2)"
                        return false
                    end
                    logs && @info "Two left and removed $val at idx: $this at constraint.idx = $(constraint.idx) (2)"
                    if has(search_space[other], check_other_val)
                        if !rm!(com, search_space[other], check_other_val)
                            logs && @warn "Two left but can't remove a value at constraint.idx = $(constraint.idx) and got infeasible (3)"
                            return false
                        end
                        logs && @info "Two left and removed $check_other_val at idx: $other at constraint.idx = $(constraint.idx) (3)"
                    end
                else
                    if !has(search_space[other], check_other_val)
                        if !rm!(com, search_space[this], val)
                            logs && @warn "Two left but can't remove a value at constraint.idx = $(constraint.idx) and got infeasible (4)"
                            return false
                        end
                        logs && @info "Two left and removed $val at idx: $this at constraint.idx = $(constraint.idx) (4)"
                    end
                end
            end
        end
    end

    return true
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
"""
    update_best_bound!(com::CS.CoM)

Iterate over all backtrack objects to set the new best bound for the whole search tree
"""
function update_best_bound!(com::CS.CoM)
    if any(bo -> bo.status == :Open, com.backtrack_vec)
        if com.sense == MOI.MIN_SENSE
            max_val = typemax(com.best_bound)
            com.best_bound = minimum([
                bo.status == :Open ? bo.best_bound : max_val for bo in com.backtrack_vec
            ])
        elseif com.sense == MOI.MAX_SENSE
            min_val = typemin(com.best_bound)
            com.best_bound = maximum([
                bo.status == :Open ? bo.best_bound : min_val for bo in com.backtrack_vec
            ])
        end # otherwise no update is needed
    end
end

"""
    update_best_bound!(backtrack_obj::BacktrackObj, com::CS.CoM, constraints)

Check all constraints which change the objective and update the best bound of the backtrack_obj accordingly.
Pruning should not be continued if the new best bound has changed.
Return feasible and if pruning should be continued.
"""
function update_best_bound!(backtrack_obj::BacktrackObj, com::CS.CoM, constraints)
    further_pruning = true
    feasible = true
    for constraint in constraints
        relevant = any(com.var_in_obj[i] for i in constraint.indices)
        if relevant
            feasible = prune_constraint!(
                com,
                constraint,
                constraint.fct,
                constraint.set;
                logs = false,
            )
            if !feasible
                return false, false
            end
        end
    end

    # check best_bound again
    # if best bound unchanged => continue pruning
    # otherwise try another path but don't close the current
    # -> means open new paths from here even if not pruned til the end
    new_bb = get_best_bound(com, backtrack_obj)
    if backtrack_obj.best_bound != new_bb
        further_pruning = false
    end
    if backtrack_obj.best_bound == com.best_bound
        backtrack_obj.best_bound = new_bb
        update_best_bound!(com)
    else
        backtrack_obj.best_bound = new_bb
    end
    return true, further_pruning
end

"""
    get_best_bound(com::CS.CoM, backtrack_obj::CS.BacktrackObj, obj_fct::SingleVariableObjective, vidx::Int, lb::Int, ub::Int)

Compute the best bound if we have a `SingleVariableObjective` and limit `vidx` using
    `lb <= var[vidx] <= ub` if `vidx != 0`.
Return a best bound given the constraints on `vidx`
"""
function get_best_bound(
    com::CS.CoM,
    backtrack_obj::CS.BacktrackObj,
    obj_fct::SingleVariableObjective,
    vidx::Int,
    lb::Int,
    ub::Int,
)
    com.options.lp_optimizer !== nothing && get_best_bound_lp(com, backtrack_obj, vidx, lb, ub)
    if obj_fct.vidx != vidx
        if com.sense == MOI.MIN_SENSE
            return com.search_space[obj_fct.vidx].min
        else # MAX
            return com.search_space[obj_fct.vidx].max
        end
    else
        if com.sense == MOI.MIN_SENSE
            return lb
        else
            return ub
        end
    end
end

"""
    get_best_bound(com::CS.CoM, backtrack_obj::CS.BacktrackObj, obj_fct::LinearCombinationObjective, vidx::Int, lb::Int, ub::Int)

Compute the best bound if we have a `LinearCombinationObjective` and limit `vidx` using
    `lb <= var[vidx] <= ub` if `vidx != 0`.
Return a best bound given the constraints on `vidx`
"""
function get_best_bound(
    com::CS.CoM,
    backtrack_obj::CS.BacktrackObj,
    obj_fct::LinearCombinationObjective,
    vidx::Int,
    lb::Int,
    ub::Int,
)
    indices = obj_fct.lc.indices
    coeffs = obj_fct.lc.coeffs
    objval = obj_fct.constant
    if com.sense == MOI.MIN_SENSE
        for i = 1:length(indices)
            if indices[i] == vidx
                objval += min(coeffs[i]*lb, coeffs[i]*ub)
                continue
            end
            objval += min(coeffs[i] * com.search_space[indices[i]].min, coeffs[i] * com.search_space[indices[i]].max)
        end
    else # MAX Sense
        for i = 1:length(indices)
            if indices[i] == vidx
                objval += max(coeffs[i]*lb, coeffs[i]*ub)
                continue
            end
            objval += max(coeffs[i] * com.search_space[indices[i]].min, coeffs[i] * com.search_space[indices[i]].max)
        end
    end

    # if all variables are fixed we don't have to compute several bounds
    if all(v -> isfixed(v), com.search_space)
        return objval
    end
end

function get_best_bound_lp(com, backtrack_obj, vidx, lb, ub)
    # check if last best_bound is affected
    # check that we have a parent node to maybe use the bound of the parent
    if backtrack_obj.parent_idx != 0 && vidx == 0
        use_last = true
        for variable in com.search_space
            lb = com.search_space[variable.idx].min
            ub = com.search_space[variable.idx].max
            if lb > backtrack_obj.primal_start[variable.idx] || ub < backtrack_obj.primal_start[variable.idx]
                use_last = false
            end
        end
        # best_bound is the best_bound from parent
        if use_last
            backtrack_obj.solution = backtrack_obj.primal_start
            return backtrack_obj.best_bound
        end
    end

    # compute bound using the lp optimizer
    # setting all bounds
    for variable in com.search_space
        if variable.idx == vidx
            set_lower_bound(com.lp_x[vidx], lb)
            set_upper_bound(com.lp_x[vidx], ub)
        else
            set_lower_bound(com.lp_x[variable.idx], com.search_space[variable.idx].min)
            set_upper_bound(com.lp_x[variable.idx], com.search_space[variable.idx].max)
        end
    end
    lp_backend = backend(com.lp_model)
    if MOI.supports(lp_backend, MOI.VariablePrimalStart(), MOI.VariableIndex)
        for variable in com.search_space
            v_idx = variable.idx
            MOI.set(lp_backend, MOI.VariablePrimalStart(), MOI.VariableIndex(v_idx), backtrack_obj.primal_start[v_idx])
        end
    end

    # update bounds by constraints
    # check each constraint which has `update_best_bound = true` for a better bound
    for constraint in com.constraints
        if constraint.impl.update_best_bound
            update_best_bound_constraint!(com, constraint, constraint.fct, constraint.set, vidx, lb, ub)
            for bound in constraint.bound_rhs
                set_lower_bound(com.lp_x[bound.idx], bound.lb)
                set_upper_bound(com.lp_x[bound.idx], bound.ub)
            end
        end
    end

    optimize!(com.lp_model)
    if termination_status(com.lp_model) == MOI.OPTIMAL
        backtrack_obj.solution = JuMP.value.(com.lp_x)
        return objective_value(com.lp_model)
    end
    if com.sense == MOI.MIN_SENSE
        return typemax(com.best_bound)
    end
    return typemin(com.best_bound)
end

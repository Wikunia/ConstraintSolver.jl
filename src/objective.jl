
"""
    get_best_bound(com::CS.CoM, backtrack_obj::CS.BacktrackObj, obj_fct::SingleVariableObjective, var_idx::Int, lb::Int, ub::Int)

Compute the best bound if we have a `SingleVariableObjective` and limit `var_idx` using 
    `lb <= var[var_idx] <= ub` if `var_idx != 0`.
Return a best bound given the constraints on `var_idx`
"""
function get_best_bound(
    com::CS.CoM,
    backtrack_obj::CS.BacktrackObj,
    obj_fct::SingleVariableObjective,
    var_idx::Int,
    lb::Int,
    ub::Int,
)
    if obj_fct.index != var_idx
        if com.sense == MOI.MIN_SENSE
            return com.search_space[obj_fct.index].min
        else # MAX
            return com.search_space[obj_fct.index].max
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
    get_best_bound(com::CS.CoM, backtrack_obj::CS.BacktrackObj, obj_fct::LinearCombinationObjective, var_idx::Int, lb::Int, ub::Int)

Compute the best bound if we have a `LinearCombinationObjective` and limit `var_idx` using 
    `lb <= var[var_idx] <= ub` if `var_idx != 0`.
Return a best bound given the constraints on `var_idx`
"""
function get_best_bound(
    com::CS.CoM,
    backtrack_obj::CS.BacktrackObj,
    obj_fct::LinearCombinationObjective,
    var_idx::Int,
    lb::Int,
    ub::Int,
)
    indices = obj_fct.lc.indices
    coeffs = obj_fct.lc.coeffs
    objval = obj_fct.constant
    if com.sense == MOI.MIN_SENSE
        for i = 1:length(indices)
            if indices[i] == var_idx
                objval += min(coeffs[i]*lb, coeffs[i]*ub)
                continue
            end
            objval += min(coeffs[i] * com.search_space[indices[i]].min, coeffs[i] * com.search_space[indices[i]].max)
        end
    else # MAX Sense
        for i = 1:length(indices)
            if indices[i] == var_idx
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
    
    com.options.lp_optimizer === nothing && return objval
    
    # check if last best_bound is affected
    # check that we have a parent node to maybe use the bound of the parent
    if backtrack_obj.parent_idx != 0 && var_idx == 0
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
        if variable.idx == var_idx 
            set_lower_bound(com.lp_x[var_idx], lb)
            set_upper_bound(com.lp_x[var_idx], ub)
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
            update_best_bound_constraint!(com, constraint, constraint.fct, constraint.set, var_idx, lb, ub)
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

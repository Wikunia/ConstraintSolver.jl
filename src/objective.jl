
"""
    get_best_bound(com::CS.CoM, obj_fct::SingleVariableObjective, var_idx::Int, left_side::Bool, var_bound::Int)

Compute the best bound if we have a `SingleVariableObjective` and limit `var_idx` using either a `<=` or a `>=` bound 
with `var_bound` and `left_side`. `left_side = true` means we have a `<=` bound
Return a best bound given the constraints on `var_idx`
"""
function get_best_bound(
    com::CS.CoM,
    obj_fct::SingleVariableObjective,
    var_idx::Int,
    left_side::Bool,
    var_bound::Int,
)
    if obj_fct.index != var_idx
        if com.sense == MOI.MIN_SENSE
            return com.search_space[obj_fct.index].min
        else # MAX
            return com.search_space[obj_fct.index].max
        end
    else
        if com.sense == MOI.MIN_SENSE
            if left_side
                return com.search_space[obj_fct.index].min
            else
                return var_bound
            end
        else
            if left_side
                return var_bound
            else
                return com.search_space[obj_fct.index].max
            end
        end
    end
end

"""
    get_best_bound(com::CS.CoM, obj_fct::LinearCombinationObjective, var_idx::Int, left_side::Bool, var_bound::Int)

Compute the best bound if we have a `LinearCombinationObjective` and limit `var_idx` using either a `<=` or a `>=` bound 
with `var_bound` and `left_side`. `left_side = true` means we have a `<=` bound
Return a best bound given the constraints on `var_idx`
"""
function get_best_bound(
    com::CS.CoM,
    obj_fct::LinearCombinationObjective,
    var_idx::Int,
    left_side::Bool,
    var_bound::Int,
)
    indices = obj_fct.lc.indices
    coeffs = obj_fct.lc.coeffs
    objval = obj_fct.constant
    if com.sense == MOI.MIN_SENSE
        for i = 1:length(indices)
            if indices[i] == var_idx
                if left_side && coeffs[i] >= 0
                    objval += coeffs[i] * com.search_space[indices[i]].min
                elseif left_side || coeffs[i] >= 0
                    objval += coeffs[i] * var_bound
                else
                    objval += coeffs[i] * com.search_space[indices[i]].max
                end
                continue
            end
            if coeffs[i] >= 0
                objval += coeffs[i] * com.search_space[indices[i]].min
            else
                objval += coeffs[i] * com.search_space[indices[i]].max
            end
        end
    else # MAX Sense
        for i = 1:length(indices)
            if indices[i] == var_idx
                if !left_side && coeffs[i] >= 0
                    objval += coeffs[i] * com.search_space[indices[i]].max
                elseif !left_side || coeffs[i] >= 0
                    objval += coeffs[i] * var_bound
                else
                    objval += coeffs[i] * com.search_space[indices[i]].min
                end
                continue
            end
            if coeffs[i] >= 0
                objval += coeffs[i] * com.search_space[indices[i]].max
            else
                objval += coeffs[i] * com.search_space[indices[i]].min
            end
        end
    end

    # check each constraint which has `check_in_best_bound = true` for a better bound
    # if all variables are fixed we don't have to compute several bounds
    if all(v -> isfixed(v), com.search_space)
        return objval
    end

    for constraint in com.constraints
        if constraint.check_in_best_bound
            constrained_bound = get_constrained_best_bound(
                com,
                constraint,
                constraint.fct,
                constraint.set,
                com.objective,
                var_idx,
                left_side,
                var_bound,
            )
            if com.sense == MOI.MIN_SENSE && constrained_bound > objval
                objval = constrained_bound
            elseif com.sense == MOI.MAX_SENSE && constrained_bound < objval
                objval = constrained_bound
            end
        end
    end
    return objval
end

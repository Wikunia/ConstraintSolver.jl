
"""
    get_best_bound(com::CS.CoM, obj_fct::SingleVariableObjective, var_idx::Int, val::Int)

Return the best objective if `var_idx` is set to `val` and we have a SingleVariableObjective
"""
function get_best_bound(com::CS.CoM, obj_fct::SingleVariableObjective, var_idx::Int, val::Int)
    returnType = typeof(com.best_bound)
    if obj_fct.index != var_idx
        if com.sense == MOI.MIN_SENSE
            return convert(returnType, com.search_space[obj_fct.index].min)
        else # MAX
            return convert(returnType, com.search_space[obj_fct.index].max)
        end
    else
        return convert(returnType, val)
    end
end

"""
    get_best_bound(com::CS.CoM, obj_fct::LinearCombinationObjective, var_idx::Int, val::Int)

Return the best objective if `var_idx` is set to `val` and we have a linear function as our objective
"""
function get_best_bound(com::CS.CoM, obj_fct::LinearCombinationObjective, var_idx::Int, val::Int)
    indices = obj_fct.lc.indices
    coeffs = obj_fct.lc.coeffs
    objval = obj_fct.constant
    if com.sense == MOI.MIN_SENSE
        for i=1:length(indices)
            if indices[i] == var_idx
                objval += coeffs[i]*val
                continue
            end
            if coeffs[i] >= 0
                objval += coeffs[i]*com.search_space[indices[i]].min
            else
                objval += coeffs[i]*com.search_space[indices[i]].max
            end
        end
    else # MAX Sense
        for i=1:length(indices)
            if indices[i] == var_idx
                objval += coeffs[i]*val
                continue
            end
            if coeffs[i] >= 0
                objval += coeffs[i]*com.search_space[indices[i]].max
            else
                objval += coeffs[i]*com.search_space[indices[i]].min
            end
        end
    end

    # check each constraint which has `check_in_best_bound = true` for a better bound
    # if all variables are fixed we don't have to compute several bounds
    if all(v->isfixed(v), com.search_space)
        return objval
    end
    log = false
    if com.search_space[1].min <= 1 <= com.search_space[1].max && 
        com.search_space[2].min <= 7 <= com.search_space[2].max &&
        com.search_space[3].min <= 1 <= com.search_space[3].max &&
        com.search_space[4].min <= 9 <= com.search_space[4].max &&
        com.search_space[5].min <= 7 <= com.search_space[5].max
       
       log = true
    end
    log && println(">>>>>>>>>>>>>>>>>>>>>>>>>>>")
    log && println("objval: $objval")
    log && println(com.search_space)
    for constraint in com.constraints
        if constraint.check_in_best_bound
            constrained_bound = get_constrained_best_bound(com, constraint, constraint.fct, constraint.set, com.objective, var_idx, val; log=log)
            log && println("constrained_bound: $constrained_bound")
            if com.sense == MOI.MIN_SENSE && constrained_bound > objval
                objval = constrained_bound
                # err()
            elseif com.sense == MOI.MAX_SENSE && constrained_bound < objval
                objval = constrained_bound
            end
        end
    end
    log && println("<<<<<<<<<<<<<<<<<<<<<<<<<")
    # err
    return objval
end

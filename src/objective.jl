
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
    return objval
end

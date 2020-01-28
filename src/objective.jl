
"""
    single_variable_objective(com::CS.CoM, var_idx::Int, val::Int)

Return the best objective if `var_idx` is set to `val`
"""
function single_variable_objective(com::CS.CoM, var_idx::Int, val::Int)
    returnType = typeof(com.best_bound)
    if com.objective.index != var_idx
        if com.sense == MOI.MIN_SENSE
            return convert(returnType, com.search_space[com.objective.index].min)
        else # MAX
            return convert(returnType, com.search_space[com.objective.index].max)
        end
    else
        return convert(returnType, val)
    end
end

"""
    linear_combination_objective(com::CS.CoM, var_idx::Int, val::Int)

Return the best objective if `var_idx` is set to `val`
"""
function linear_combination_objective(com::CS.CoM, var_idx::Int, val::Int)
    objective = com.objective
    indices = objective.lc.indices
    coeffs = objective.lc.coeffs
    objval = objective.constant
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

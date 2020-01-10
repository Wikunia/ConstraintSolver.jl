
"""
    single_variable_objective(com::CS.CoM, var_idx::Int, val::Int)

Return the best objective if `var_idx` is set to `val`
"""
function single_variable_objective(com::CS.CoM, var_idx::Int, val::Int)
    if com.objective.index != var_idx
        if com.sense == MOI.MIN_SENSE 
            return com.search_space[com.objective.index].min
        else # MAX
            return com.search_space[com.objective.index].max
        end
    else
        return val
    end
end
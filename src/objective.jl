function vars_max(vars::Vector{CS.Variable})
    return MinMaxObjective(vars_max, [var.idx for var in vars])
end

function vars_max(com::CS.CoM, set_var_idx, var_val)
    objective = com.objective
    # return the minimal possible maximum value
    sense = com.sense
    search_space = com.search_space
    c_best_bound = minimum(values(search_space[1]))
    if sense == :Min
        for var_idx in objective.indices
            if var_idx == set_var_idx
                min_val = var_val
            else
                min_val = minimum(values(search_space[var_idx]))
            end
            if min_val > c_best_bound
                c_best_bound = min_val
            end
        end
    end
    @assert c_best_bound > 0
    return c_best_bound
end
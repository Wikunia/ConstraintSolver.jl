"""
    all_different(com::CS.CoM, indices)

Tries to reduce the search space by the all_different constraint. 
Fixes values and then sets com.changed to true for the corresponding index.
Returns true if the problem is still feasible and false otherwise, in that cases it also throws a warning.
"""
function all_different(com::CS.CoM, indices)
    fixed_vals , unfixed_indices = fixed_vs_unfixed(com, indices)
    fixed_vals_set = Set(fixed_vals)
    # check if one value is used more than once
    if length(fixed_vals_set) < length(fixed_vals)
        @warn "The problem is infeasible"
        return false
    end

    for i in unfixed_indices
        for pv in fixed_vals
            if haskey(com.search_space[i], pv) 
                delete!(com.search_space[i], pv)

                if length(com.search_space[i]) == 1
                    only_value = collect(keys(com.search_space[i]))[1]
                    if in(fixed_vals_set, only_value)
                        @warn "The problem is infeasible"
                        return false
                    end
                    com.grid[i] = only_value
                    delete!(com.search_space, i)
                    com.changed[i] = true
                    break 
                end
            end
        end
    end

    return true
end

"""
    all_different(com::CoM, indices, value::Int)

Returns whether the constraint can be still fulfilled.
"""
function all_different(com::CoM, indices, value::Int)
    for i in indices
        if value == com.grid[i]
            return false
        end
    end
    return true
end
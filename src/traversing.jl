"""
    get_next_node(com::CS.CoM, backtrack_vec::Vector{BacktrackObj{T}}, sorting) where T <: Real

Get the next node we want to prune on if there is any. Currently this uses best first search and if two 
nodes have the same `best_bound` the deeper one is chosen.
Return whether a node was found and the corresponding backtrack_obj
"""
function get_next_node(
    com::CS.CoM,
    backtrack_vec::Vector{BacktrackObj{T}},
    sorting,
) where {T<:Real}
    # if there is no objective or sorting is set to false
    found = false
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    backtrack_obj = backtrack_vec[1]

    if com.sense == MOI.FEASIBILITY_SENSE || !sorting
        l = length(backtrack_vec)
        backtrack_obj = backtrack_vec[l]
        while backtrack_obj.status != :Open
            l -= 1
            if l == 0
                break
            end
            backtrack_obj = backtrack_vec[l]
        end
        if l != 0
            found = true
        end
    else # sort for objective
        # don't actually sort => just get the best backtrack idx
        # the one with the best bound and if same best bound choose the one with higher depth
        l = 0
        best_fac_bound = typemax(Int)
        best_depth = 0
        found_sol = length(com.bt_solution_ids) > 0
        nopen_nodes = 0
        for i = 1:length(backtrack_vec)
            bo = backtrack_vec[i]
            if bo.status == :Open
                nopen_nodes += 1
                if found_sol
                    if obj_factor * bo.best_bound < best_fac_bound || (
                        obj_factor * bo.best_bound == best_fac_bound &&
                        bo.depth > best_depth
                    )
                        l = i
                        best_depth = bo.depth
                        best_fac_bound = obj_factor * bo.best_bound
                    end
                else
                    if bo.depth > best_depth || (
                        obj_factor * bo.best_bound < best_fac_bound &&
                        bo.depth == best_depth
                    )
                        l = i
                        best_depth = bo.depth
                        best_fac_bound = obj_factor * bo.best_bound
                    end
                end
            end
        end

        if l != 0
            backtrack_obj = backtrack_vec[l]
            found = true
        end
    end
    # if we found the optimal solution or one feasible
    # => check whether all solutions are requested
    if !found && com.options.all_solutions
        l = length(backtrack_vec)
        backtrack_obj = backtrack_vec[l]
        while backtrack_obj.status == :Closed
            l -= 1
            if l == 0
                break
            end
            backtrack_obj = backtrack_vec[l]
        end
        if l != 0
            found = true
        end
    end

    if !found && com.options.all_optimal_solutions
        l = length(backtrack_vec)
        backtrack_obj = backtrack_vec[l]
        # get an obj which has the same bound as the optimal solution
        while backtrack_obj.best_bound != com.best_sol || backtrack_obj.status == :Closed
            l -= 1
            if l == 0
                break
            end
            backtrack_obj = backtrack_vec[l]
        end
        if l != 0
            found = true
        end
    end

    return found, backtrack_obj
end

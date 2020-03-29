function get_first_open(backtrack_vec)
    found = false
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
    return found, backtrack_obj
end

function get_next_node(
    com::CS.CoM,
    backtrack_vec::Vector{BacktrackObj{T}},
    sorting
) where {T<:Real}
    found, backtrack_obj = get_next_node(com, com.traverse_strategy, backtrack_vec, sorting)

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

"""
    get_next_node(com::CS.CoM, ::TraverseBFS, backtrack_vec::Vector{BacktrackObj{T}}, sorting) where T <: Real

Get the next node we want to prune on if there is any. This uses best first search and if two 
nodes have the same `best_bound` the deeper one is chosen. 
Check other `get_next_node` functions for other possible traverse strategies.
Return whether a node was found and the corresponding backtrack_obj
"""
function get_next_node(
    com::CS.CoM,
    traverse::TraverseBFS,
    backtrack_vec::Vector{BacktrackObj{T}},
    sorting
) where {T<:Real}
    found = false
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    backtrack_obj = backtrack_vec[1]

    # if there is no objective or sorting is set to false
    if com.sense == MOI.FEASIBILITY_SENSE || !sorting
        return get_first_open(backtrack_vec)
    end
    # sort for objective
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
            if obj_factor * bo.best_bound < best_fac_bound || (
                obj_factor * bo.best_bound == best_fac_bound &&
                bo.depth > best_depth
            )
                l = i
                best_depth = bo.depth
                best_fac_bound = obj_factor * bo.best_bound
            end
        end
    end

    if l != 0
        backtrack_obj = backtrack_vec[l]
        found = true
    end
    return found, backtrack_obj
end

"""
    get_next_node(com::CS.CoM, ::TraverseDFS, backtrack_vec::Vector{BacktrackObj{T}}, sorting) where T <: Real

Get the next node we want to prune on if there is any. This uses depth first search and if two 
nodes have the same depth the one with the better `best_bound` is chosen. 
Check other `get_next_node` functions for other possible traverse strategies.
Return whether a node was found and the corresponding backtrack_obj
"""
function get_next_node(
    com::CS.CoM,
    traverse::TraverseDFS,
    backtrack_vec::Vector{BacktrackObj{T}},
    sorting
) where {T<:Real}
    found = false
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    backtrack_obj = backtrack_vec[1]

    # if there is no objective or sorting is set to false
    if com.sense == MOI.FEASIBILITY_SENSE || !sorting
        return get_first_open(backtrack_vec)
    end # sort for depth
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

    if l != 0
        backtrack_obj = backtrack_vec[l]
        found = true
    end

    return found, backtrack_obj
end
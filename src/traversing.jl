"""
    changed_traverse_strategy!(com::CS.CoM, old_traverse_strategy)

Changing from one traverse strategy to another. This means that the priority queue
needs to be rebuilt from scratch.
"""
function changed_traverse_strategy!(com::CS.CoM, old_traverse_strategy)
    old_backtrack_pq = deepcopy(com.backtrack_pq)
    com.backtrack_pq = PriorityQueue{Int,Priority}(Base.Order.Reverse)
    if old_traverse_strategy == Val(:DFS)
        for elem in old_backtrack_pq
            idx = elem.first
            priority = elem.second
            com.backtrack_pq[idx] =
                PriorityBFS(priority.bound, priority.depth, priority.neg_idx)
        end
    else # :BFS
        for elem in old_backtrack_pq
            idx = elem.first
            priority = elem.second
            com.backtrack_pq[idx] =
                PriorityDFS(priority.depth, priority.bound, priority.neg_idx)
        end
    end
end


"""
    set_update_backtrack_pq!(com::CS.CoM, backtrack_obj::BacktrackObj; best_bound=backtrack_obj.best_bound)

Inserts or updates the value for `backtrack_obj` in the priority queue: `backtrack_pq`.
It uses the best bound of the object by default but can be overwritten with `; best_bound=other`
"""
function set_update_backtrack_pq!(
    com::CS.CoM,
    backtrack_obj::BacktrackObj;
    best_bound = backtrack_obj.best_bound,
)
    if com.traverse_strategy == Val(:DFS)
        if com.sense == MOI.MIN_SENSE
            com.backtrack_pq[backtrack_obj.idx] =
                PriorityDFS(backtrack_obj.depth, -best_bound, -backtrack_obj.idx)
        else
            com.backtrack_pq[backtrack_obj.idx] =
                PriorityDFS(backtrack_obj.depth, best_bound, -backtrack_obj.idx)
        end
    else
        if com.sense == MOI.MIN_SENSE
            com.backtrack_pq[backtrack_obj.idx] =
                PriorityBFS(-best_bound, backtrack_obj.depth, -backtrack_obj.idx)
        else
            com.backtrack_pq[backtrack_obj.idx] =
                PriorityBFS(best_bound, backtrack_obj.depth, -backtrack_obj.idx)
        end
    end
end

"""
    add2priorityqueue(com::CS.CoM, backtrack_obj::BacktrackObj)

Add the backtrack_obj to the priority queue `backtrack_pq`
"""
function add2priorityqueue(com::CS.CoM, backtrack_obj::BacktrackObj)
    set_update_backtrack_pq!(com, backtrack_obj)
end


"""
    close_node!(com::CS.CoM, node_idx::Int)

Close a backtrack object node if not already closed by setting the status to `:Closed`
and deleting it from the priority queue `backtrack_pq`
"""
function close_node!(com::CS.CoM, node_idx::Int)
    backtrack_vec = com.backtrack_vec
    backtrack_vec[node_idx].status == :Closed && return
    backtrack_vec[node_idx].status = :Closed

    delete!(com.backtrack_pq, node_idx)
end

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
    sorting,
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
    get_next_node(com::CS.CoM, ::Val{:BFS}, backtrack_vec::Vector{BacktrackObj{T}}, sorting) where T <: Real

Get the next node we want to prune on if there is any. This uses best first search and if two
nodes have the same `best_bound` the deeper one is chosen.
Check other `get_next_node` functions for other possible traverse strategies.
Return whether a node was found and the corresponding backtrack_obj
"""
function get_next_node(
    com::CS.CoM,
    ::Val{:BFS},
    backtrack_vec::Vector{BacktrackObj{T}},
    sorting,
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
    for i in 1:length(backtrack_vec)
        bo = backtrack_vec[i]
        if bo.status == :Open
            if obj_factor * bo.best_bound < best_fac_bound ||
               (obj_factor * bo.best_bound == best_fac_bound && bo.depth > best_depth)
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
    get_next_node(com::CS.CoM, :Val{:DFS}, backtrack_vec::Vector{BacktrackObj{T}}, sorting) where T <: Real

Get the next node we want to prune on if there is any. This uses depth first search and if two
nodes have the same depth the one with the better `best_bound` is chosen.
Check other `get_next_node` functions for other possible traverse strategies.
Return whether a node was found and the corresponding backtrack_obj
"""
function get_next_node(
    com::CS.CoM,
    ::Val{:DFS},
    backtrack_vec::Vector{BacktrackObj{T}},
    sorting,
) where {T<:Real}
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    backtrack_obj = backtrack_vec[1]

    # if sorting is set to false
    if !sorting
        return get_first_open(backtrack_vec)
    end # sort for depth
    # don't actually sort => just get the best backtrack idx
    # the one with the highest depth and if same choose better bound
    isempty(com.backtrack_pq) && return false, backtrack_obj

    backtrack_idx, _ = peek(com.backtrack_pq)

    backtrack_obj = backtrack_vec[backtrack_idx]

    return true, backtrack_obj
end

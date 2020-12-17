function create_log_node(com)
    com.input[:logs] || return
    back_idx = length(com.backtrack_vec)
    parent_idx = 0
    if length(com.backtrack_vec) > 0
        status = com.backtrack_vec[back_idx].status
        vidx = com.backtrack_vec[back_idx].vidx
        lb = com.backtrack_vec[back_idx].lb
        ub = com.backtrack_vec[back_idx].ub
        best_bound = com.backtrack_vec[back_idx].best_bound

        parent_idx = com.backtrack_vec[back_idx].parent_idx
    else # for initial solve
        status = :Closed
        vidx = 0
        lb = 0
        ub = 0
        best_bound = com.best_bound
    end

    tree_log_node = TreeLogNode(
        back_idx,
        status,
        true, # feasible
        best_bound,
        -1, # initial step nr
        vidx,
        lb,
        ub,
        Dict{Int,Vector{Int}}(), # var_states
        Dict{Int,Vector{Tuple{Symbol,Int,Int,Int}}}(), # var_changes
        Dict{Int,Float64}(), # activity
        Vector{TreeLogNode{typeof(best_bound)}}(), # children
    )


    push!(com.logs, tree_log_node)
    @assert length(com.logs) == back_idx

    if parent_idx > 0
        push!(com.logs[parent_idx].children, tree_log_node)
    end

end

function update_log_node!(com, back_idx; feasible = nothing)
    com.input[:logs] || return
    tree_log_node = com.logs[back_idx]

    # never set an infeasible one to feasible
    # + infeasible nodes are closed
    if feasible !== nothing
        tree_log_node.feasible = feasible
        close_node!(com, back_idx)
    end

    tree_log_node.status = com.backtrack_vec[back_idx].status
    tree_log_node.vidx = com.backtrack_vec[back_idx].vidx
    tree_log_node.lb = com.backtrack_vec[back_idx].lb
    tree_log_node.ub = com.backtrack_vec[back_idx].ub
    tree_log_node.best_bound = com.backtrack_vec[back_idx].best_bound
    tree_log_node.step_nr = com.backtrack_vec[back_idx].step_nr


    variables = com.search_space
    if tree_log_node.status == :Closed
        for var in variables
            # easier to visualize if we save it every step even if unchanged
            # increases time and file size but that is not critical if keep_logs is `true` anyway.
            # Hopefully :D
            tree_log_node.var_states[var.idx] = sort!(values(var))
            if length(var.changes[back_idx]) > 0
                tree_log_node.var_changes[var.idx] = var.changes[back_idx]
            end
            tree_log_node.activity[var.idx] = var.activity
        end
    end
end

function bfs_list(start_node::CS.TreeLogNode)
    to_process = Vector{CS.TreeLogNode}()
    depths = Vector{Int}()
    nodes_list = Vector{CS.TreeLogNode}()
    num_children = Vector{Int}()

    push!(to_process, start_node)
    push!(depths, 0)
    node = deepcopy(start_node)
    node.children = TreeLogNode[]

    while !isempty(to_process)
        current_node = popfirst!(to_process)
        depth = popfirst!(depths)

        node = deepcopy(current_node)
        push!(num_children, length(node.children))
        node.children = TreeLogNode[]
        push!(nodes_list, node)

        for child_node in current_node.children
            push!(to_process, child_node)
            push!(depths, depth + 1)
        end
    end
    return nodes_list, num_children
end

"""
    sanity_check_logs(log)

Check that
- there are at least 2 closed nodes
- no step nr > 0 is used more than once
"""
function sanity_check_log(log)
    nodes_list, num_children = bfs_list(log)
    nclosed = 0
    step_nrs = Int[]
    for i in 1:length(nodes_list)
        node = nodes_list[i]
        num_child = num_children[i]
        if node.status == :Closed
            nclosed += 1
        end
        if node.step_nr > 0
            push!(step_nrs, node.step_nr)
        end
    end
    passed = nclosed >= 2 && allunique(step_nrs)
    !passed && write("FAILED.json", JSON.json(log))
    return passed
end

function same_logs(log1, log2)
    nodes_list1, num_children1 = bfs_list(log1)
    nodes_list2, num_children2 = bfs_list(log2)
    if length(nodes_list1) != length(nodes_list2)
        println("Different length")
        return false
    end
    for i in 1:length(nodes_list1)
        node1 = nodes_list1[i]
        node2 = nodes_list2[i]
        num_child1 = num_children1[i]
        num_child2 = num_children2[i]
        if num_child1 != num_child2
            println("Different number of children at: ", i)
            return false
        end

        if node1.id != node2.id ||
           node1.status != node2.status ||
           node1.best_bound != node2.best_bound ||
           node1.step_nr != node2.step_nr ||
           node1.vidx != node2.vidx ||
           node1.lb != node2.lb ||
           node1.ub != node2.ub ||
           node1.var_states != node2.var_states ||
           node1.feasible != node2.feasible
            println("Not identical at i=", i)
            println("node1: ")
            println(
                "id: ",
                node1.id,
                " status: ",
                node1.status,
                " best_bound: ",
                node1.best_bound,
                " step_nr: ",
                node1.step_nr,
            )
            println(
                "vidx: ",
                node1.vidx,
                " lb:",
                node1.lb,
                " ub: ",
                node1.ub,
                " var_states: ",
                node1.var_states,
            )
            println("node2: ")
            println(
                "id: ",
                node2.id,
                " status: ",
                node2.status,
                " best_bound: ",
                node2.best_bound,
                " step_nr: ",
                node2.step_nr,
            )
            println(
                "vidx: ",
                node2.vidx,
                " lb:",
                node2.lb,
                " ub: ",
                node2.ub,
                " var_states: ",
                node2.var_states,
            )
            return false
        end
    end
    return true
end

function get_logs(com::CS.CoM)
    logs = Dict{Symbol,Any}()
    nvars = length(com.search_space)

    logs[:init] = Vector{Vector{Int}}(undef, nvars)
    for var in com.init_search_space
        logs[:init][var.idx] = values(var)
    end

    logs[:tree] = com.logs[1]
    return logs
end

function add_variable_mapping(log, args...)
    var_mapping = Dict{Symbol,Any}()
    for var in args
        # transpose such that JSON has it row by row instead of column by column
        var_mapping[var.first] = var_idx.(var.second)'
    end
    log[:variable_mapping] = var_mapping
end

"""
    save_logs(com::CS.CoM, filepath)

Save the tree structure and some additional problem information in a json file `filepath`.
Can be only used if `keep_logs` is set to `true` in the [`solve!`](@ref) call.
"""
function save_logs(com::CS.CoM, filepath, vars...)
    logs = get_logs(com)
    add_variable_mapping(logs, vars...)
    write(filepath, JSON.json(logs))
end

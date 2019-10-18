function log_one_node(com, nvars, back_idx)
    tree_log_node = TreeLogNode()
    tree_log_node.id = back_idx
    parent_idx = 0
    if length(com.backtrack_vec) > 0
        tree_log_node.status = com.backtrack_vec[back_idx].status
        tree_log_node.var_idx = com.backtrack_vec[back_idx].variable_idx
        tree_log_node.set_val = com.backtrack_vec[back_idx].pval
        tree_log_node.best_bound = com.backtrack_vec[back_idx].best_bound

        parent_idx = com.backtrack_vec[back_idx].parent_idx
    else # for initial solve
        tree_log_node.status = :Closed
        tree_log_node.var_idx = 0
        tree_log_node.set_val = 0
    end
    tree_log_node.var_changes = Dict{Int64,Vector{Tuple{Symbol, Int64, Int64, Int64}}}()
    tree_log_node.var_states = Dict{Int64,Vector{Int64}}()
    if tree_log_node.status == :Closed
        for var in com.search_space
            if length(var.changes[back_idx]) > 0
                tree_log_node.var_states[var.idx] = sort!(values(var))
                tree_log_node.var_changes[var.idx] = var.changes[back_idx]
            end
        end
    end
    tree_log_node.children = Vector{TreeLogNode}()
    if parent_idx > 0
        changed = false
        for (i,child) in enumerate(com.logs[parent_idx].children)
            if child.id == back_idx
                com.logs[parent_idx].children[i] = tree_log_node
                changed = true
                break
            end
        end
        if !changed
            push!(com.logs[parent_idx].children, tree_log_node)
        end
    end 
    return tree_log_node
end

function save_logs(com::CS.CoM, filepath)
    logs = Dict{Symbol, Any}()
    nvars = length(com.search_space)

    logs[:init] = Vector{Vector{Int64}}(undef, nvars)
    for var in com.init_search_space
        logs[:init][var.idx] = values(var)
    end

    logs[:tree] = com.logs[1]
    write(filepath, JSON.json(logs))
end
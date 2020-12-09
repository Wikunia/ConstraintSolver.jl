"""
    general_tree_test(com::CS.CoM)

Performs some general tests which are nice to test if a new constraint works as intended and implements the necessary methods.
Should be called only if optimize was called already as this works on the final tree structure.
It fails if no backtracking was used as this method should only be called when at least some backtracking steps are needed.
Additionally `keep_logs` needs to be activated to make it work.
What it does:
    - Tests `checkout_from_to!` which basically means jumping from one node in the tree to another.
        - Checks there whether this produces the same search space as before at that stage.
"""
function general_tree_test(com::CS.CoM)
    if length(com.logs) == 0
        @error "Make sure that keep_logs is set to true."
    end
    @assert length(com.logs) > 10
    c_backtrack_idx = com.c_backtrack_idx
    Random.seed!(241)
    n_backtracks = length(com.logs)
    path = Int[c_backtrack_idx]
    path_type = Symbol[]
    all_correct = true
    n_children_tests = 0

    for t in 1:100
        status = :Open
        next_idx = 0
        while status == :Open
            # don't allow root node as that might cause chaos :D
            next_idx = rand(2:n_backtracks)
            status = com.logs[next_idx].status
        end
        CS.checkout_from_to!(com, c_backtrack_idx, next_idx)

        if com.backtrack_vec[next_idx].parent_idx != 0
            c_backtrack_idx = com.backtrack_vec[next_idx].parent_idx

            c_search_space = com.search_space
            # this is a dict =>
            expected_search_space = com.logs[c_backtrack_idx].var_states
            correct = true
            for var in c_search_space
                if sort(CS.values(var)) != sort(expected_search_space[var.idx])
                    println("var.idx: $(var.idx)")
                    println("vals: $(CS.values(var))")
                    println("expected: $(expected_search_space[var.idx])")
                    correct = false
                    all_correct = false
                end
            end
            if !correct
                @error "There were errors on the jump path: $path before pruning the last step"
            end
        end

        c_backtrack_idx = next_idx

        # if it has children
        if length(com.logs[c_backtrack_idx].children) > 0 && n_children_tests < 5
            com.c_backtrack_idx = c_backtrack_idx
            vidx = com.logs[c_backtrack_idx].vidx
            n_children_tests += 1
            # test that pruning produces the same output as before

            for var in com.search_space
                var.changes[c_backtrack_idx] = Vector{Tuple{Symbol,Int,Int,Int}}()
            end
            @assert CS.remove_above!(
                com,
                com.search_space[vidx],
                com.logs[c_backtrack_idx].ub,
            )
            @assert CS.remove_below!(
                com,
                com.search_space[vidx],
                com.logs[c_backtrack_idx].lb,
            )

            if com.sense != MOI.FEASIBILITY_SENSE
                constraints = com.constraints[com.subscription[vidx]]
                feasible, further_pruning = CS.update_best_bound!(
                    com.backtrack_vec[c_backtrack_idx],
                    com,
                    constraints,
                )
                @assert feasible
            end

            @assert CS.prune!(com)
            CS.call_finished_pruning!(com)
            push!(path_type, :prune)
        else
            # prune the last step based on saved information instead
            CS.restore_prune!(com, c_backtrack_idx)
            push!(path_type, :restore_prune)
        end

        push!(path, c_backtrack_idx)
        c_search_space = com.search_space
        # this is a dict =>
        expected_search_space = com.logs[c_backtrack_idx].var_states
        correct = true
        for var in c_search_space
            if sort(CS.values(var)) != sort(expected_search_space[var.idx])
                println("var.idx: $(var.idx)")
                println("vals: $(CS.values(var))")
                println("expected: $(expected_search_space[var.idx])")
                correct = false
                all_correct = false
            end
        end
        if !correct
            @error "There were errors on the jump path: $path"
            @error "More info about the path: $path_type"
        end
        @assert correct
    end
    if n_children_tests != 5
        @error "Make sure that you have more feasible nodes in the search tree to test more."
    end
    @assert n_children_tests == 5

    # back to solved state
    CS.checkout_from_to!(com, c_backtrack_idx, path[1])
    # prune the last step
    CS.restore_prune!(com, path[1])

    return all_correct
end

function is_solved(com::CS.CoM)
    variables = com.search_space
    all_fixed = all(v -> CS.isfixed(v), variables)
    if !all_fixed
        @error "Not all variables are fixed"
        return false
    end
    for constraint in com.constraints
        values = CS.value.(com.search_space[constraint.indices])
        c_solved =
            CS.is_constraint_solved(constraint, constraint.fct, constraint.set, values)
        c_violated = CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
        if !c_solved || c_violated
            @error "Constraint $(constraint.idx) is not solved"
            @error "Info about constraint: $(typeof(constraint)), $(typeof(constraint.fct)), $(typeof(constraint.set))"
            return false
        end
    end
    return true
end

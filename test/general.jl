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
    all_correct = true
    for t = 1:10
        status = :Open
        next_idx = 0
        while status == :Open
            next_idx = rand(1:n_backtracks)
            status = com.logs[next_idx].status
        end
        
        CS.checkout_from_to!(com, c_backtrack_idx, next_idx)
        # prune the last step
        CS.restore_prune!(com, next_idx)
        c_backtrack_idx = next_idx
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
        end
        @assert correct
    end
    # back to solved state 
    CS.checkout_from_to!(com, c_backtrack_idx, path[1])
    # prune the last step
    CS.restore_prune!(com, path[1])

    return all_correct
end
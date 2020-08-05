#================================

    All kinds of functions related to pruning

=================================#

"""
    get_next_prune_constraint(com::CS.CoM, constraint_idxs_vec)

Check which function will be called for pruning next. This is based on `constraint_idxs_vec`. The constraint with the lowest
value is chosen and if two have the same value the constraint hash is checked.
Return the best value and the constraint index. Return a constraint index of 0 if there is no constraint with a less than maximal value
"""
function get_next_prune_constraint(com::CS.CoM, constraint_idxs_vec)
    best_ci = 0
    best_open = typemax(Int)
    best_hash = typemax(UInt64)
    for ci = 1:length(constraint_idxs_vec)
        if constraint_idxs_vec[ci] <= best_open
            if constraint_idxs_vec[ci] < best_open || com.constraints[ci].hash < best_hash
                best_ci = ci
                best_open = constraint_idxs_vec[ci]
                best_hash = com.constraints[ci].hash
            end
        end
    end
    return best_open, best_ci
end

"""
    open_possibilities(search_space, indices)

Return the sum of possible values for the given list of indices. Does not count 1 if the value is fixed
"""
function open_possibilities(search_space, indices)
    open = 0
    for vi in indices
        if !isfixed(search_space[vi])
            open += nvalues(search_space[vi])
        end
    end
    return open
end

"""
    prune!(com::CS.CoM; pre_backtrack=false, all=false, only_once=false, initial_check=false)

Prune based on changes by initial solve or backtracking. The information for it is stored in each variable.
There are several parameters:
`pre_backtrack` when set to true `com.info.in_backtrack_calls` is incremented
`all` instead of only looking at changes each constraint is check at least once (if there are open values)
`only_once` Just run on the changed constraints or `all` once instead of repeatedly until nothing can be pruned
`initial_check` Checks on `all` constraints and also checks if variables are set for the whole constraint
    whether the constraint is fulfilled or the problem is infeasible.
Return whether it's still feasible
"""
function prune!(
    com::CS.CoM;
    pre_backtrack = false,
    all = false,
    only_once = false,
    initial_check = false,
)
    feasible = true
    N = typemax(Int)
    search_space = com.search_space
    prev_var_length = zeros(Int, length(search_space))
    constraint_idxs_vec = fill(N, length(com.constraints))
    # get all constraints which need to be called (only once)
    current_backtrack_id = com.c_backtrack_idx
    for var in search_space
        new_var_length = length(var.changes[current_backtrack_id])
        if new_var_length > 0 || all || initial_check
            prev_var_length[var.idx] = new_var_length
            for ci in com.subscription[var.idx]
                inner_constraint = com.constraints[ci]
                constraint_idxs_vec[inner_constraint.idx] =
                    open_possibilities(search_space, inner_constraint.indices)
            end
        end
    end

    # while we haven't called every constraint
    while true
        b_open_constraint = false
        # will be changed or b_open_constraint => false
        open_pos, ci = get_next_prune_constraint(com, constraint_idxs_vec)
        # no open values => don't need to call again
        if open_pos == 0 && !initial_check
            constraint_idxs_vec[ci] = N
            continue
        end
        # checked all
        if open_pos == N
            break
        end
        constraint_idxs_vec[ci] = N
        constraint = com.constraints[ci]

        feasible =
            prune_constraint!(com, constraint, constraint.fct, constraint.set; logs = false)
        if !pre_backtrack
            com.info.in_backtrack_calls += 1
        else
            com.info.pre_backtrack_calls += 1
        end
        if !feasible
            break
        end

        # if we changed another variable increase the level of the constraints to call them later
        for vidx in constraint.indices
            var = search_space[vidx]
            new_var_length = length(var.changes[current_backtrack_id])
            if new_var_length > prev_var_length[var.idx]
                prev_var_length[var.idx] = new_var_length
                for ci in com.subscription[var.idx]
                    # don't call the same constraint again. 
                    # Each constraint should prune as much as possible 
                    if ci != constraint.idx
                        inner_constraint = com.constraints[ci]
                        # if initial check or don't add constraints => update only those which already have open possibilities
                        if (only_once || initial_check) &&
                           constraint_idxs_vec[inner_constraint.idx] == N
                            continue
                        end
                        constraint_idxs_vec[inner_constraint.idx] =
                            open_possibilities(search_space, inner_constraint.indices)
                    end
                end
            end
        end
    end
    return feasible
end

"""
    restore_prune!(com::CS.CoM, prune_steps)

Prune the search space based on a list of backtracking indices `prune_steps`.
"""
function restore_prune!(com::CS.CoM, prune_steps)
    search_space = com.search_space
    for backtrack_idx in prune_steps
        for var in search_space
            for change in var.changes[backtrack_idx]
                fct_symbol = change[1]
                val = change[2]
                if fct_symbol == :fix
                    fix!(com, var, val; changes = false, check_feasibility = false)
                elseif fct_symbol == :rm
                    rm!(com, var, val; changes = false, check_feasibility = false)
                elseif fct_symbol == :remove_above
                    remove_above!(com, var, val; changes = false, check_feasibility = false)
                elseif fct_symbol == :remove_below
                    remove_below!(com, var, val; changes = false, check_feasibility = false)
                else
                    throw(ErrorException("There is no pruning function for $fct_symbol"))
                end
            end
        end
        com.c_backtrack_idx = backtrack_idx
    end
    call_restore_pruning!(com, prune_steps)
end

"""
    single_reverse_pruning!(search_space, vidx::Int, prune_int::Int, prune_fix::Int)

Reverse a single variable using `prune_int` (number of value removals) and `prune_fix` (new last_ptr if not 0).
"""
function single_reverse_pruning!(search_space, vidx::Int, prune_int::Int, prune_fix::Int)
    if prune_int > 0
        var = search_space[vidx]
        l_ptr = max(1, var.last_ptr)

        new_l_ptr = var.last_ptr + prune_int
        min_val, max_val = extrema(var.values[l_ptr:new_l_ptr])
        if min_val < var.min
            var.min = min_val
        end
        if max_val > var.max
            var.max = max_val
        end
        var.last_ptr = new_l_ptr
    end
    if prune_fix > 0
        var = search_space[vidx]
        var.last_ptr = prune_fix

        min_val, max_val = extrema(var.values[1:prune_fix])
        if min_val < var.min
            var.min = min_val
        end
        if max_val > var.max
            var.max = max_val
        end
        var.first_ptr = 1
    end
end

"""
    reverse_pruning!(com, backtrack_idx)

Reverse the changes made by a specific backtrack object
"""
function reverse_pruning!(com::CS.CoM, backtrack_idx::Int)
    com.c_backtrack_idx = backtrack_idx
    search_space = com.search_space
    for var in search_space
        v_idx = var.idx
        for change in Iterators.reverse(var.changes[backtrack_idx])
            single_reverse_pruning!(search_space, v_idx, change[4], change[3])
        end
    end
    for var in search_space
        length(var.changes[backtrack_idx]) == 0 && continue
        var.idx > length(com.subscription) && continue
        for ci in com.subscription[var.idx]
            constraint = com.constraints[ci]
            if constraint.impl.single_reverse_pruning
                single_reverse_pruning_constraint!(com, constraint, constraint.fct, constraint.set,
                                                    var, backtrack_idx)
            end
        end
    end
    for constraint in com.constraints
        if constraint.impl.reverse_pruning
            reverse_pruning_constraint!(com, constraint, constraint.fct, constraint.set, backtrack_idx)
        end
    end
    com.c_backtrack_idx = com.backtrack_vec[backtrack_idx].parent_idx
end
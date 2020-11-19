"""
    get_split_pvals(com, ::Val{:Auto}, var::Variable)

Splits the possible values into two by using either :smallest or :biggest value and the rest.
It depends on whether it's a satisfiability or optimization problem and whether the variable has a positive
or negative coefficient + minimization or maximization
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Auto}, var::Variable)
    @assert var.min != var.max
    if isa(com.objective, LinearCombinationObjective)
        linear_comb = com.objective.lc
        for i in 1:length(linear_comb.indices)
            if linear_comb.indices[i] == var.idx
                coeff = linear_comb.coeffs[i]
                factor = com.sense == MOI.MIN_SENSE ? -1 : 1
                if coeff*factor > 0
                    return get_split_pvals(com, Val(:Biggest), var)
                else
                    return get_split_pvals(com, Val(:Smallest), var)
                end
            end
        end
    end
    # fallback for satisfiability or not in objective
    return get_split_pvals(com, Val(:Smallest), var)
end

"""
    get_split_pvals(com, ::Val{:InHalf}, var::Variable)

Splits the possible values into two by obtaining the mean value.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:InHalf}, var::Variable)
    pvals = values(var)
    @assert length(pvals) >= 2
    mean_val = mean(pvals)
    leq = typemin(Int)
    geq = typemax(Int)
    lb = typemax(Int)
    ub = typemin(Int)
    for pval in pvals
        if pval <= mean_val && pval > leq
            leq = pval
        elseif pval > mean_val && pval < geq
            geq = pval
        end
        if pval < lb
            lb = pval
        end
        if pval > ub
            ub = pval
        end
    end
    return lb, leq, geq, ub
end

"""
    get_split_pvals(com, ::Val{:Smallest}, var::Variable)

Splits the possible values into two by using the smallest value and the rest.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Smallest}, var::Variable)
    @assert var.min != var.max
    right_lb = partialsort(values(var), 2)
    return var.min, var.min, right_lb, var.max
end

"""
    get_split_pvals(com, ::Val{:Biggest}, var::Variable)

Splits the possible values into two by using the biggest value and the rest.
Return lb, leq, geq, ub => the bounds for the lower part and the bounds for the upper part
"""
function get_split_pvals(com, ::Val{:Biggest}, var::Variable)
    @assert var.min != var.max
    left_ub = partialsort(values(var), 2; rev=true)
    return var.min, left_ub, var.max, var.max
end

"""
    get_next_branch_variable(com::CS.CoM)

Get the next weak index for backtracking. This will be the next branching variable.
Return whether there is an unfixed variable and a best index
"""
function get_next_branch_variable(com::CS.CoM)
    return get_next_branch_variable(com, com.branch_strategy)
end

function get_next_branch_variable(com::CS.CoM, ::Val{:OLD})
    lowest_num_pvals = typemax(Int)
    biggest_inf = -1
    best_vidx = -1
    biggest_dependent = typemax(Int)
    is_in_objective = false
    found = false

    for vidx = 1:length(com.search_space)
        if !isfixed(com.search_space[vidx])
            num_pvals = nvalues(com.search_space[vidx])
            inf = com.bt_infeasible[vidx]
            if !is_in_objective && com.var_in_obj[vidx]
                is_in_objective = true
                lowest_num_pvals = num_pvals
                biggest_inf = inf
                best_vidx = vidx
                found = true
                continue
            end
            if !is_in_objective || com.var_in_obj[vidx]
                if inf >= biggest_inf
                    if inf > biggest_inf || num_pvals < lowest_num_pvals
                        lowest_num_pvals = num_pvals
                        biggest_inf = inf
                        best_vidx = vidx
                        found = true
                    end
                end
            end
        end
    end
    return found, best_vidx
end

function get_next_branch_variable(com::CS.CoM, ::Val{:Random})
    variables = com.search_space
    is_free = com.activity_vars.is_free
    if com.c_backtrack_idx == 1
        com.activity_vars.is_free = zeros(Bool, length(variables))
        is_free = com.activity_vars.is_free
    else
        is_free .= false
    end

    for variable in variables
        if !isfixed(variable)
            is_free[variable.idx] = true
        end
    end
    found = any(is_free)
    vidx = -1
    if found
        vidx = sample(CS_RNG, 1:length(variables), Weights(is_free))
    end
    return found, vidx
end

"""
    probe_until(com::CS.CoM, until_fct)

Start probing from current node:
- Create paths in a depth first search way and use a random branch variable strategy
- Update activity
- Return if `until_fct(com)` evaluates to true
This creates new `BacktrackObj` inside `backtrack_vec` which get overwritten in each probe
"""
function probe_until(com::CS.CoM, until_fct)
    probe_start_id = com.c_backtrack_idx
    num_backtrack_objs = length(com.backtrack_vec)
    temp_nidxs = Set{Int}()
    before_logs = com.input[:logs]
    com.input[:logs] = false
    while !until_fct(com)

        copied_traverse_strategy = com.traverse_strategy
        com.traverse_strategy = Val(:DFS)

        backtrack_idx_before = com.c_backtrack_idx

        feasible, backtrack_ids = probe(com, num_backtrack_objs)
        checkout_new_node!(com,  com.c_backtrack_idx, probe_start_id)
        restore_prune!(com, probe_start_id)

        # reset backtrack_vec and var.changes
        for variable in com.search_space
            for backtrack_id in backtrack_ids
                empty!(variable.changes[backtrack_id])
            end
        end

        for backtrack_id in backtrack_ids
            com.backtrack_vec[backtrack_id].status = :Closed
            push!(temp_nidxs, backtrack_id)
        end

        com.c_backtrack_idx = probe_start_id
    end
    com.input[:logs] = before_logs
    sorted_temp_nidxs = sort!(collect(temp_nidxs); rev=true)
    for nidx in sorted_temp_nidxs
        splice!(com.backtrack_vec, nidx)
    end
    return get_next_branch_variable(com, Val(:ABS))
end

"""
    probe(com::CS.CoM, num_backtrack_objs)

Probe from node id: `num_backtrack_objs`
- Follow a DFS path by random selection of a branching variable
- Update activity
Return if feasible and the created backtrack ids along the way
"""
function probe(com::CS.CoM, num_backtrack_objs)
    backtrack_vec = com.backtrack_vec
    found, vidx = get_next_branch_variable(com, Val(:Random))

    step_nr = 1
    backtrack_ids = Int[]
    parent_idx = backtrack_vec[num_backtrack_objs].parent_idx
    parent_idx == 0 && (parent_idx = 1)
    depth = backtrack_vec[num_backtrack_objs].depth
    depth == 0 && (depth = 1)
    num_backtrack_objs = add2backtrack_vec!(
        backtrack_vec,
        com,
        num_backtrack_objs,
        parent_idx,
        depth,
        step_nr,
        vidx
    )

    last_backtrack_id = 0

    feasible = true
    found = true
    while feasible
        step_nr += 1

        if last_backtrack_id != 0
            backtrack_vec[last_backtrack_id].status = :Closed
        end

        found, backtrack_obj = get_next_node(com, backtrack_vec, true)
        !found && break

        vidx = backtrack_obj.variable_idx
        com.c_backtrack_idx = backtrack_obj.idx
        push!(backtrack_ids, backtrack_obj.idx)
        checkout_new_node!(com, last_backtrack_id, backtrack_obj.idx)
        last_backtrack_id = com.c_backtrack_idx

        feasible = set_bounds!(com, backtrack_obj)
        !feasible && break

        constraints = com.constraints[com.subscription[vidx]]

        feasible = prune!(com)
        call_finished_pruning!(com)

        com.activity_vars.nprobes += 1
        update_activity!(com; in_probing_phase=true)
        !feasible && break

        found, vidx = get_next_branch_variable(com, Val(:Random))
        !found && break

        last_backtrack_obj = backtrack_vec[backtrack_obj.idx]
        num_backtrack_objs = add2backtrack_vec!(
            backtrack_vec,
            com,
            num_backtrack_objs,
            last_backtrack_obj.idx,
            last_backtrack_obj.depth + 1,
            step_nr,
            vidx;
            check_bound = true,
            only_one = true
        )
    end
    return feasible, backtrack_ids
end

function update_activity!(com; in_probing_phase=false)
    # update activity
    c_backtrack_idx = com.c_backtrack_idx
    γ = com.options.activity_decay
    for variable in com.search_space
        if length(variable.changes[c_backtrack_idx]) > 0
            variable.activity += 1
        elseif nvalues(variable) > 1 && !in_probing_phase
            variable.activity *= γ
        end
    end
end

function get_next_branch_variable(com::CS.CoM, ::Val{:ABS})
    # probing phase currently probes 10*#variables
    in_probing_phase = com.activity_vars.nprobes <= 20*length(com.search_space)

    update_activity!(com; in_probing_phase=in_probing_phase)

    if in_probing_phase
        return probe_until(com, (com)->com.activity_vars.nprobes > 20*length(com.search_space))
    end

    #=
    if com.info.backtrack_fixes == 100*length(com.search_space)+1
        for variable in com.search_space
            if !isfixed(variable)
                println("vidx: $(variable.idx) -> $(variable.activity)")
            end
        end
    end
    =#

    # activity bases search
    is_in_objective = false
    highest_activity = -1.0
    best_vidx = -1
    found = false

    for variable in com.search_space
        if !isfixed(variable)
            vidx = variable.idx
            num_pvals = nvalues(variable)
            activity_ratio = variable.activity / num_pvals
            if !is_in_objective && com.var_in_obj[vidx]
                highest_activity = activity_ratio
                is_in_objective = true
                found = true
                best_vidx = vidx
                continue
            end
            if !is_in_objective || com.var_in_obj[vidx]
                if activity_ratio >= highest_activity
                    highest_activity = activity_ratio
                    best_vidx = vidx
                    found = true
                end
            end
        end
    end
    return found, best_vidx
end

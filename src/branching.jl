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
    return get_split_pvals(com, rand(CS_RNG, [Val(:Smallest), Val(:Biggest)]), var)
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
    get_split_pvals(com, ::Val{:Random}, var::Variable)

Splits the possible values into two by using a random value for the left branch
**Attention:** The right branch is not useable atm.
"""
function get_split_pvals(com, ::Val{:Random}, var::Variable)
    @assert var.min != var.max
    val = rand(CS_RNG, values(var))
    return val, val, typemin(typeof(val)), typemin(typeof(val))
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

function still_probing(n, μ, variance)
    n < 2 && return true
    for i in 1:length(μ)
        σ = sqrt(variance[i])
        if tdistcdf(n-1, 0.05)*(σ/sqrt(n)) > 0.2*μ[i]
            range = tdistcdf(n-1, 0.05)*(σ/sqrt(n))
            return true
        end
    end
    return false
end

"""
    probe_until(com::CS.CoM, until_fct)

Start probing from current node:
- Create paths in a depth first search way and use a random branch variable strategy
- Update activity
This creates new `BacktrackObj` inside `backtrack_vec` which get overwritten in each probe
"""
function probe_until(com::CS.CoM)
    num_backtrack_objs = length(com.backtrack_vec)
    mean_activities = [var.activity for var in com.search_space]
    variance_activities = zeros(length(com.search_space))
    n = 1
    while n < 100 && still_probing(n, mean_activities, variance_activities)
        n += 1
        ccom = deepcopy(com)
        ccom.traverse_strategy = Val(:DFS)
        ccom.branch_split = Val(:Random)
        root_feasible, feasible, activities = probe(ccom)
        for i in 1:length(com.search_space)
            new_mean = mean_activities[i] + (activities[i]-mean_activities[i]) / n
            # update std: https://math.stackexchange.com/questions/102978/incremental-computation-of-standard-deviation
            if n != 1
                variance_activities[i] = ((n-2)*variance_activities[i]+(n-1)*(mean_activities[i]-new_mean)^2+(activities[i]-new_mean)^2)/(n-1)
            end
            mean_activities[i] = new_mean
        end
        # if root infeasible we can remove that setting completely
        if !root_feasible
            backtrack_obj = ccom.backtrack_vec[ccom.c_backtrack_idx]
            vidx = backtrack_obj.vidx
            vidx == 0 && break # all variables are fixed already
            # use the variable from com not ccom to remove it from the actual model
            variable = com.search_space[vidx]
            lb = backtrack_obj.lb
            ub = backtrack_obj.ub
            for val in lb:ub
                if has(variable, val)
                    rm!(com, variable, val)
                end
            end
        end
        if (!isempty(ccom.solutions))
            push!(com.solutions, ccom.solutions[1])
        end
    end
    for i in 1:length(com.search_space)
        com.search_space[i].activity = mean_activities[i]
    end
end

"""
    probe(com::CS.CoM)

Probe from node root node
- Follow a DFS path by random selection of a branching variable
- Update activity
Return if feasible and the created backtrack ids along the way
"""
function probe(com::CS.CoM)
    activities = zeros(length(com.search_space))

    backtrack_vec = com.backtrack_vec
    found, vidx = get_next_branch_variable(com, Val(:Random))
    !found && return false, false, activities

    step_nr = 1
    parent_idx = 1
    depth = 1
    num_backtrack_objs = add2backtrack_vec!(
        backtrack_vec,
        com,
        1,
        parent_idx,
        depth,
        step_nr,
        vidx;
        only_one = true
    )

    last_backtrack_id = 0
    root_feasible = true
    feasible = true
    found = true
    while feasible
        step_nr += 1
        step_nr % 50 == 0 && println("step_nr: $step_nr")

        if last_backtrack_id != 0
            backtrack_vec[last_backtrack_id].status = :Closed
            com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space)
        end

        found, backtrack_obj = get_next_node(com, backtrack_vec, true)
        !found && break

        vidx = backtrack_obj.vidx
        com.c_backtrack_idx = backtrack_obj.idx
        checkout_new_node!(com, last_backtrack_id, backtrack_obj.idx)
        if com.input[:logs]
            com.logs[backtrack_obj.idx].step_nr = step_nr
        end

        last_backtrack_id = com.c_backtrack_idx

        feasible = set_bounds!(com, backtrack_obj)
        if !feasible
            com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space; feasible=false)
            if step_nr == 2
                root_feasible = false
            end
            break
        end

        constraints = com.constraints[com.subscription[vidx]]

        feasible = prune!(com)
        call_finished_pruning!(com)

        update_probe_activity!(activities, com)
        if !feasible
            com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space; feasible=false)
            if step_nr == 2
               root_feasible = false
            end
            break
        end

        found, vidx = get_next_branch_variable(com, Val(:Random))
        if com.input[:logs]
            com.logs[backtrack_obj.idx] =
                log_one_node(com, length(com.search_space), backtrack_obj.idx, step_nr)
        end
        if !found
            add_new_solution!(com, backtrack_vec, backtrack_obj, false)
            break
        end

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
    return root_feasible, feasible, activities
end

function update_activity!(com)
    c_backtrack_idx = com.c_backtrack_idx
    backtrack_obj = com.backtrack_vec[c_backtrack_idx]
    branch_vidx = backtrack_obj.vidx
    γ = com.options.activity_decay
    for variable in com.search_space
        variable.idx == branch_vidx && continue
        if nvalues(variable) > 1
            variable.activity *= γ
        end
        if length(variable.changes[c_backtrack_idx]) > 0
            variable.activity += 1
        end
    end
end

function update_probe_activity!(activities, com)
    c_backtrack_idx = com.c_backtrack_idx
    backtrack_obj = com.backtrack_vec[c_backtrack_idx]
    branch_vidx = backtrack_obj.vidx
    for variable in com.search_space
        variable.idx == branch_vidx && continue
        if length(variable.changes[c_backtrack_idx]) > 0
            activities[variable.idx] += 1
        end
    end
end

function get_next_branch_variable(com::CS.CoM, ::Val{:ABS})
    update_activity!(com)

    if com.in_probing_phase
        com.in_probing_phase = false
        probe_until(com)
    end

    #=
    for variable in com.search_space
        if variable.idx == 12
            println("vidx: $(variable.idx) -> $(variable.activity)")
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

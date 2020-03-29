module ConstraintSolver

using MatrixNetworks
using JSON
using MathOptInterface
using Statistics
using JuMP:
    @variable,
    @constraint,
    @objective,
    Model,
    optimizer_with_attributes,
    VariableRef,
    backend,
    set_optimizer,
    direct_model,
    optimize!,
    objective_value, 
    set_lower_bound,
    set_upper_bound,
    termination_status
import JuMP.sense_to_set
import JuMP
using Formatting

const MOI = MathOptInterface
const MOIU = MOI.Utilities

include("TableLogger.jl")
include("options.jl")

const CS = ConstraintSolver
include("types.jl")

const CoM = ConstraintSolverModel
include("type_inits.jl")

include("util.jl")
include("branching.jl")
include("traversing.jl")
include("lp_model.jl")
include("MOI_wrapper/MOI_wrapper.jl")
include("printing.jl")
include("logs.jl")
include("hashes.jl")
include("Variable.jl")
include("objective.jl")
include("linearcombination.jl")
include("constraints/all_different.jl")
include("constraints/eq_sum.jl")
include("constraints/less_than.jl")
include("constraints/svc.jl")
include("constraints/equal.jl")
include("constraints/not_equal.jl")

"""
    add_var!(com::CS.CoM, from::Int, to::Int; fix=nothing)

Adding a variable to the constraint model `com`. The variable is discrete and has the possible values from,..., to.
If the variable should be fixed to something one can use the `fix` keyword i.e `add_var!(com, 1, 9; fix=5)`
"""
function add_var!(com::CS.CoM, from::Int, to::Int; fix = nothing)
    ind = length(com.search_space) + 1
    changes = Vector{Vector{Tuple{Symbol,Int,Int,Int}}}()
    push!(changes, Vector{Tuple{Symbol,Int,Int,Int}}())
    var = Variable(
        ind,
        from,
        to,
        1,
        to - from + 1,
        from:to,
        1:to-from+1,
        1 - from,
        from,
        to,
        changes,
        true,
        true,
        fix !== nothing,
        true,
    )
    if fix !== nothing
        fix!(com, var, fix)
    end
    push!(com.search_space, var)
    push!(com.subscription, Int[])
    push!(com.bt_infeasible, 0)
    return var
end

"""
    fulfills_constraints(com::CS.CoM, index, value)

Return whether the model is still feasible after setting the variable at position `index` to `value`.
"""
function fulfills_constraints(com::CS.CoM, index, value)
    # variable doesn't have any constraint
    if index > length(com.subscription)
        return true
    end
    feasible = true
    for ci in com.subscription[index]
        constraint = com.constraints[ci]
        feasible =
            still_feasible(com, constraint, constraint.fct, constraint.set, value, index)
        if !feasible
            break
        end
    end
    return feasible
end

"""
    set_pvals!(com::CS.CoM, constraint::Constraint)

Compute the possible values inside this constraint and set it as constraint.pvals
"""
function set_pvals!(com::CS.CoM, constraint::Constraint)
    indices = constraint.indices
    variables = Variable[v for v in com.search_space[indices]]
    pvals_intervals = Vector{NamedTuple}()
    push!(pvals_intervals, (from = variables[1].lower_bound, to = variables[1].upper_bound))
    for (i, ind) in enumerate(indices)
        extra_from = variables[i].min
        extra_to = variables[i].max
        comp_inside = false
        for cpvals in pvals_intervals
            if extra_from >= cpvals.from && extra_to <= cpvals.to
                # completely inside the interval already
                comp_inside = true
                break
            elseif extra_from >= cpvals.from && extra_from <= cpvals.to
                extra_from = cpvals.to + 1
            elseif extra_to <= cpvals.to && extra_to >= cpvals.from
                extra_to = cpvals.from - 1
            end
        end
        if !comp_inside && extra_to >= extra_from
            push!(pvals_intervals, (from = extra_from, to = extra_to))
        end
    end
    pvals = collect(pvals_intervals[1].from:pvals_intervals[1].to)
    for interval in pvals_intervals[2:end]
        pvals = vcat(pvals, collect(interval.from:interval.to))
    end
    constraint.pvals = pvals
end

"""
    add_constraint!(com::CS.CoM, constraint::Constraint)

Add a constraint to the model i.e `add_constraint!(com, a != b)`
"""
function add_constraint!(com::CS.CoM, constraint::Constraint)
    constraint.idx = length(com.constraints) + 1
    push!(com.constraints, constraint)
    set_pvals!(com, constraint)
    for (i, ind) in enumerate(constraint.indices)
        push!(com.subscription[ind], constraint.idx)
    end
end


"""
    prune!(com::CS.CoM, prune_steps::Vector{Int})

Prune the search space based on a list of backtracking indices `prune_steps`.
"""
function prune!(com::CS.CoM, prune_steps::Vector{Int})
    search_space = com.search_space
    for backtrack_idx in prune_steps
        for var in search_space
            for change in var.changes[backtrack_idx]
                fct_symbol = change[1]
                val = change[2]
                if fct_symbol == :fix
                    fix!(com, var, val; changes = false)
                elseif fct_symbol == :rm
                    rm!(com, var, val; changes = false)
                elseif fct_symbol == :remove_above
                    remove_above!(com, var, val; changes = false)
                elseif fct_symbol == :remove_below
                    remove_below!(com, var, val; changes = false)
                else
                    throw(ErrorException("There is no pruning function for $fct_symbol"))
                end
            end
        end
    end
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
        for var_idx in constraint.indices
            var = search_space[var_idx]
            new_var_length = length(var.changes[current_backtrack_id])
            if new_var_length > prev_var_length[var.idx]
                prev_var_length[var.idx] = new_var_length
                for ci in com.subscription[var.idx]
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
    single_reverse_pruning!(search_space, index::Int, prune_int::Int, prune_fix::Int)

Reverse a single variable using `prune_int` (number of value removals) and `prune_fix` (new last_ptr if not 0).
"""
function single_reverse_pruning!(search_space, index::Int, prune_int::Int, prune_fix::Int)
    if prune_int > 0
        var = search_space[index]
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
        var = search_space[index]
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
    search_space = com.search_space
    for var in search_space
        v_idx = var.idx

        for change in Iterators.reverse(var.changes[backtrack_idx])
            single_reverse_pruning!(search_space, v_idx, change[4], change[3])
        end
    end
end

"""
    get_best_bound(com::CS.CoM, backtrack_obj::BacktrackObj; var_idx=0, left_side=true, var_bound=0)

Return the best bound if setting the variable with idx: `var_idx` to 
    <= `var_bound` if `var_idx != 0` and `left_side` 
    >= `var_bound` if `var_idx != 0` and `!left_side` 
Without an objective function return 0.
"""
function get_best_bound(com::CS.CoM, backtrack_obj::BacktrackObj; var_idx = 0, left_side = true, var_bound = 0)
    if com.sense == MOI.FEASIBILITY_SENSE
        return zero(com.best_bound)
    end
    return get_best_bound(com, backtrack_obj, com.objective, var_idx, left_side, var_bound)
end

"""
    checkout_from_to!(com::CS.CoM, from_idx::Int, to_idx::Int)

Change the state of the search space given the current position in the tree (`from_idx`) and the index we want 
to change to (`to_idx`)
"""
function checkout_from_to!(com::CS.CoM, from_idx::Int, to_idx::Int)
    backtrack_vec = com.backtrack_vec
    from = backtrack_vec[from_idx]
    to = backtrack_vec[to_idx]
    if to.parent_idx == from.idx
        return
    end
    reverse_pruning!(com, from.idx)

    prune_steps = Vector{Int}()
    # first go to same level if new is higher in the tree
    if to.depth < from.depth
        depth = from.depth
        parent_idx = from.parent_idx
        parent = backtrack_vec[parent_idx]
        while to.depth < depth
            reverse_pruning!(com, parent_idx)
            parent = backtrack_vec[parent_idx]
            parent_idx = parent.parent_idx
            depth -= 1
        end
        if parent_idx == to.parent_idx
            return
        else
            from = parent
        end
    elseif from.depth < to.depth
        depth = to.depth
        parent_idx = to.parent_idx
        parent = backtrack_vec[parent_idx]
        while from.depth < depth
            pushfirst!(prune_steps, parent_idx)
            parent = backtrack_vec[parent_idx]
            parent_idx = parent.parent_idx
            depth -= 1
        end


        to = parent
        if backtrack_vec[prune_steps[1]].parent_idx == from.parent_idx
            prune!(com, prune_steps)
            return
        end
    end
    @assert from.depth == to.depth
    # same diff but different parent
    # => level up until same parent
    while from.parent_idx != to.parent_idx
        reverse_pruning!(com, from.parent_idx)
        from = backtrack_vec[from.parent_idx]

        pushfirst!(prune_steps, to.parent_idx)
        to = backtrack_vec[to.parent_idx]
    end

    prune!(com, prune_steps)
end

"""
    update_best_bound!(backtrack_obj::BacktrackObj, com::CS.CoM, constraints)

Check all constraints which change the objective and update the best bound of the backtrack_obj accordingly.
Pruning should not be continued if the new best bound has changed.
Return feasible and if pruning should be continued.
"""
function update_best_bound!(backtrack_obj::BacktrackObj, com::CS.CoM, constraints)
    further_pruning = true
    feasible = true
    for constraint in constraints
        relevant = false
        for obj_index in com.objective.indices
            if obj_index in constraint.indices
                relevant = true
                break
            end
        end
        if relevant
            feasible = prune_constraint!(
                com,
                constraint,
                constraint.fct,
                constraint.set;
                logs = false,
            )
            if !feasible
                return false, false
            end
        end
    end

    # check best_bound again
    # if best bound unchanged => continue pruning
    # otherwise try another path but don't close the current
    # -> means open new paths from here even if not pruned til the end
    new_bb = get_best_bound(com, backtrack_obj)
    if backtrack_obj.best_bound != new_bb
        further_pruning = false
    end
    if backtrack_obj.best_bound == com.best_bound
        backtrack_obj.best_bound = new_bb
        update_best_bound!(com)
    else
        backtrack_obj.best_bound = new_bb
    end
    return true, further_pruning
end

"""
    update_best_bound!(com::CS.CoM)

Iterate over all backtrack objects to set the new best bound for the whole search tree
"""
function update_best_bound!(com::CS.CoM)
    if any(bo -> bo.status == :Open, com.backtrack_vec)
        if com.sense == MOI.MIN_SENSE
            max_val = typemax(com.best_bound)
            com.best_bound = minimum([
                bo.status == :Open ? bo.best_bound : max_val for bo in com.backtrack_vec
            ])
        elseif com.sense == MOI.MAX_SENSE
            min_val = typemin(com.best_bound)
            com.best_bound = maximum([
                bo.status == :Open ? bo.best_bound : min_val for bo in com.backtrack_vec
            ])
        end # otherwise no update is needed
    end
end

"""
    set_state_to_best_sol!(com::CS.CoM, last_backtrack_id::Int)

Set the state of the model to the best solution found
"""
function set_state_to_best_sol!(com::CS.CoM, last_backtrack_id::Int)
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    backtrack_vec = com.backtrack_vec
    # find one of the best solutions
    sol, sol_id = findmin([
        backtrack_vec[sol_id].best_bound * obj_factor for sol_id in com.bt_solution_ids
    ])
    backtrack_id = com.bt_solution_ids[sol_id]
    checkout_from_to!(com, last_backtrack_id, backtrack_id)
    # prune the last step as checkout_from_to! excludes the to part
    prune!(com, [backtrack_id])
end

"""
    get_split_pvals(pvals::Vector{Int})

Splits the possible values into two by obtaining the mean value.
Return the biggest int in pvals which is ≤ the mean and the smallest int in pvals which is bigger than mean
"""
function get_split_pvals(pvals::Vector{Int})
    @assert length(pvals) >= 2
    mean_val = mean(pvals)
    leq = typemin(Int)
    geq = typemax(Int)
    for pval in pvals
        if pval <= mean_val && pval > leq
            leq = pval
        elseif pval > mean_val && pval < geq
            geq = pval
        end
    end
    return leq, geq
end

"""
    addBacktrackObj2Backtrack_vec!(backtrack_vec, backtrack_obj, com::CS.CoM, num_backtrack_objs, step_nr)

Add a backtrack object to the backtrack vector and create necessary vectors and maybe include it in the logs
"""
function addBacktrackObj2Backtrack_vec!(
    backtrack_vec,
    backtrack_obj,
    com::CS.CoM,
    num_backtrack_objs,
    step_nr,
)
    push!(backtrack_vec, backtrack_obj)
    for v in com.search_space
        push!(v.changes, Vector{Tuple{Symbol,Int,Int,Int}}())
    end
    if com.input[:logs]
        push!(
            com.logs,
            log_one_node(com, length(com.search_space), num_backtrack_objs, step_nr),
        )
    end
end

"""
    backtrack_vec::Vector{BacktrackObj{T}}, com::CS.CoM{T},num_backtrack_objs, parent_idx, depth, step_nr, ind, pvals; check_bound=false)

Create two branches with two additional BacktrackObj and add them to backtrack_vec 
"""
function add2backtrack_vec!(
    backtrack_vec::Vector{BacktrackObj{T}},
    com::CS.CoM{T},
    num_backtrack_objs,
    parent_idx,
    depth,
    step_nr,
    ind,
    pvals;
    check_bound = false,
) where {T<:Real}
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    leq_val, geq_val = get_split_pvals(pvals)
    num_backtrack_objs += 1
    backtrack_obj = BacktrackObj(
        num_backtrack_objs,
        parent_idx,
        depth,
        :Open,
        ind,
        true, # left branch
        leq_val,
        backtrack_vec[parent_idx].best_bound, # initialize with parent best bound
        backtrack_vec[parent_idx].solution,
        zeros(length(com.search_space))
    )
    backtrack_obj.best_bound = get_best_bound(com, backtrack_obj; var_idx = ind, left_side = true, var_bound = leq_val)
    # only include nodes which have a better objective than the current best solution if one was found already
    if !check_bound || (
        backtrack_obj.best_bound * obj_factor < com.best_sol ||
        length(com.bt_solution_ids) == 0
    )
        addBacktrackObj2Backtrack_vec!(
            backtrack_vec,
            backtrack_obj,
            com,
            num_backtrack_objs,
            step_nr,
        )
    else
        num_backtrack_objs -= 1
    end
    # right branch
    num_backtrack_objs += 1
    backtrack_obj = BacktrackObj(
        num_backtrack_objs,
        parent_idx,
        depth,
        :Open,
        ind,
        false, # right branch
        geq_val,
        backtrack_vec[parent_idx].best_bound,
        backtrack_vec[parent_idx].solution,
        zeros(length(com.search_space))
    )
    backtrack_obj.best_bound = get_best_bound(com, backtrack_obj; var_idx = ind, left_side = false, var_bound = geq_val)
    if !check_bound || (
        backtrack_obj.best_bound * obj_factor < com.best_sol ||
        length(com.bt_solution_ids) == 0
    )
        addBacktrackObj2Backtrack_vec!(
            backtrack_vec,
            backtrack_obj,
            com,
            num_backtrack_objs,
            step_nr,
        )
    else
        num_backtrack_objs -= 1
    end

    return num_backtrack_objs
end

"""
    set_bounds!(com, backtrack_obj)

Set lower/upper bounds for the current variable index `backtrack_obj.variable_idx`.
Return if simple removable is still feasible
"""
function set_bounds!(com, backtrack_obj)
    ind = backtrack_obj.variable_idx
    if backtrack_obj.left_side
        !remove_above!(com, com.search_space[ind], backtrack_obj.var_bound) && return false
    else
        !remove_below!(com, com.search_space[ind], backtrack_obj.var_bound) && return false
    end
    return true
end

"""
    add_new_solution!(com::CS.CoM, backtrack_vec::Vector{BacktrackObj{T}}, backtrack_obj::BacktrackObj{T}, log_table) where T <: Real

A new solution was found. 
- Add it to the solutions objects
Return true if backtracking can be stopped
"""
function add_new_solution!(
    com::CS.CoM,
    backtrack_vec::Vector{BacktrackObj{T}},
    backtrack_obj::BacktrackObj{T},
    log_table,
) where {T<:Real}
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    find_more_solutions = com.options.all_solutions || com.options.all_optimal_solutions

    new_sol = get_best_bound(com, backtrack_obj)
    if length(com.bt_solution_ids) == 0 || obj_factor * new_sol <= obj_factor * com.best_sol
        push!(com.bt_solution_ids, backtrack_obj.idx)
        # also push it to the solutions object
        new_sol_obj = Solution(new_sol, CS.value.(com.search_space))
        push!(com.solutions, new_sol_obj)
        com.best_sol = new_sol
        log_table && (last_table_row = update_table_log(com, backtrack_vec; force = true))
        if com.best_sol == com.best_bound && !find_more_solutions
            return true
        end
        # set all nodes to :Worse if they can't achieve a better solution
        for bo in backtrack_vec
            if bo.status == :Open && obj_factor * bo.best_bound >= obj_factor * com.best_sol
                bo.status = :Worse
            end
        end
    else # if new solution was found but it's worse
        log_table && (last_table_row = update_table_log(com, backtrack_vec; force = true))
        if com.options.all_solutions
            new_sol_obj = Solution(new_sol, CS.value.(com.search_space))
            push!(com.solutions, new_sol_obj)
        end
    end
    return false
end

"""
    backtrack!(com::CS.CoM, max_bt_steps; sorting=true)

Start backtracking and stop after `max_bt_steps`.
If `sorting` is set to `false` the same ordering is used as when used without objective this has only an effect when an objective is used.
Return :Solved or :Infeasible if proven or `:NotSolved` if interrupted by `max_bt_steps`.
"""
function backtrack!(com::CS.CoM, max_bt_steps; sorting = true)
    found, ind = get_next_branch_variable(com)
    com.info.backtrack_fixes = 1
    find_more_solutions = com.options.all_solutions || com.options.all_optimal_solutions

    log_table = false
    if :Table in com.options.logging
        log_table = true
        println(get_header(com.options.table))
    end

    pvals = values(com.search_space[ind])
    dummy_backtrack_obj = BacktrackObj(com)

    backtrack_vec = com.backtrack_vec
    push!(backtrack_vec, dummy_backtrack_obj)

    # the first solve (before backtrack) has idx 1
    num_backtrack_objs = 1
    step_nr = 1

    num_backtrack_objs = add2backtrack_vec!(
        backtrack_vec,
        com,
        num_backtrack_objs,
        1,
        1,
        step_nr,
        ind,
        pvals,
    )
    last_backtrack_id = 0

    started = true
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1

    while length(backtrack_vec) > 0
        step_nr += 1
        # get next open backtrack object
        l = 1
        if !started
            # close the previous backtrack object
            backtrack_vec[last_backtrack_id].status = :Closed
        end
        if time() - com.start_time > com.options.time_limit
            break
        end

        !started && update_best_bound!(com)
        found, backtrack_obj = get_next_node(com, backtrack_vec, sorting)
        !found && break

        # there is no better node => return best solution
        if length(com.bt_solution_ids) > 0 &&
           obj_factor * com.best_bound >= obj_factor * com.best_sol && !find_more_solutions
            break
        end

        ind = backtrack_obj.variable_idx

        com.c_backtrack_idx = backtrack_obj.idx

        if !started
            com.c_backtrack_idx = 0
            checkout_from_to!(com, last_backtrack_id, backtrack_obj.idx)
            com.c_backtrack_idx = backtrack_obj.idx
        end

        if com.input[:logs]
            com.logs[backtrack_obj.idx].step_nr = step_nr
        end

        started = false
        last_backtrack_id = backtrack_obj.idx

        # limit the variable bounds
        !set_bounds!(com, backtrack_obj) && continue

        constraints = com.constraints[com.subscription[ind]]
        com.info.backtrack_fixes += 1

        further_pruning = true
        # first update the best bound (only constraints which have an index in the objective function)
        if com.sense != MOI.FEASIBILITY_SENSE
            feasible, further_pruning = update_best_bound!(backtrack_obj, com, constraints)
            if !feasible
                com.info.backtrack_reverses += 1
                continue
            end
        end

        if further_pruning
            # prune completely start with all that changed by the fix or by updating best bound
            feasible = prune!(com)

            if !feasible
                com.info.backtrack_reverses += 1
                continue
            end
        end

        if log_table
            last_table_row = update_table_log(com, backtrack_vec)
        end

        found, ind = get_next_branch_variable(com)
        # no index found => solution found
        if !found
            finished = add_new_solution!(com, backtrack_vec, backtrack_obj, log_table)
            finished && return :Solved
            continue
        end

        if com.info.backtrack_fixes > max_bt_steps
            return :NotSolved
        end

        if com.input[:logs]
            com.logs[backtrack_obj.idx] =
                log_one_node(com, length(com.search_space), backtrack_obj.idx, step_nr)
        end

        leafs_best_bound = get_best_bound(com, backtrack_obj)
        # if the objective can't get better we don't have to test all options
        if leafs_best_bound * obj_factor >= com.best_sol && length(com.bt_solution_ids) > 0
            continue
        end

        pvals = values(com.search_space[ind])
        last_backtrack_obj = backtrack_vec[last_backtrack_id]
        num_backtrack_objs = add2backtrack_vec!(
            backtrack_vec,
            com,
            num_backtrack_objs,
            last_backtrack_obj.idx,
            last_backtrack_obj.depth + 1,
            step_nr,
            ind,
            pvals;
            check_bound = true,
        )
    end
    if length(com.bt_solution_ids) > 0
        set_state_to_best_sol!(com, last_backtrack_id)
        com.best_bound = com.best_sol
        if time() - com.start_time > com.options.time_limit
            return :Time
        else
            return :Solved
        end
    end
    if time() - com.start_time > com.options.time_limit
        return :Time
    else
        return :Infeasible
    end
end

"""
    simplify!(com)

Simplify constraints i.e by adding new constraints which uses an implicit connection between two constraints.
i.e an `all_different` does sometimes include information about the sum.
"""
function simplify!(com)
    # check if we have all_different and sum constraints
    # (all different where every value is used)
    b_all_different = false
    b_all_different_sum = false
    b_eq_sum = false
    for constraint in com.constraints
        if isa(constraint.set, AllDifferentSet)
            b_all_different = true
            if length(constraint.indices) == length(constraint.pvals)
                b_all_different_sum = true
            end
        elseif isa(constraint.fct, SAF) && isa(constraint.set, MOI.EqualTo)
            b_eq_sum = true
        end
    end
    if b_all_different_sum && b_eq_sum
        # for each all_different constraint
        # which can be formulated as a sum constraint
        # check which sum constraints are completely inside all different
        # which are partially inside
        # compute inside sum and total sum
        n_constraints_before = length(com.constraints)
        for constraint_idx = 1:length(com.constraints)
            constraint = com.constraints[constraint_idx]

            if isa(constraint.set, AllDifferentSet)
                add_sum_constraint = true
                if length(constraint.indices) == length(constraint.pvals)
                    all_diff_sum = sum(constraint.pvals)
                    in_sum = 0
                    total_sum = 0
                    outside_indices = Int[]
                    cons_indices_dict = arr2dict(constraint.indices)
                    for variable_idx in keys(cons_indices_dict)
                        found_sum_constraint = false
                        for sub_constraint_idx in com.subscription[variable_idx]
                            # don't mess with constraints added later on
                            if sub_constraint_idx > n_constraints_before
                                continue
                            end
                            sub_constraint = com.constraints[sub_constraint_idx]
                            # it must be an equal constraint and all coefficients must be 1 otherwise we can't add a constraint
                            if isa(sub_constraint.fct, SAF) &&
                               isa(sub_constraint.set, MOI.EqualTo)
                                if all(t.coefficient == 1 for t in sub_constraint.fct.terms)
                                    found_sum_constraint = true
                                    total_sum +=
                                        sub_constraint.set.value -
                                        sub_constraint.fct.constant
                                    all_inside = true
                                    for sub_variable_idx in sub_constraint.indices
                                        if !haskey(cons_indices_dict, sub_variable_idx)
                                            all_inside = false
                                            push!(outside_indices, sub_variable_idx)
                                        else
                                            delete!(cons_indices_dict, sub_variable_idx)
                                        end
                                    end
                                    if all_inside
                                        in_sum +=
                                            sub_constraint.set.value -
                                            sub_constraint.fct.constant
                                    end
                                    break
                                end
                            end
                        end
                        if !found_sum_constraint
                            add_sum_constraint = false
                            break
                        end
                    end

                    # make sure that there are not too many outside indices
                    if add_sum_constraint && length(outside_indices) < 3
                        add_constraint!(
                            com,
                            sum(com.search_space[outside_indices]) ==
                            total_sum - all_diff_sum,
                        )
                    end
                end
            end
        end
    end
end

"""
    set_in_all_different!(com::CS.CoM)

Set `constraint.in_all_different` if all variables in the constraint are part of the same `all_different` constraint.
"""
function set_in_all_different!(com::CS.CoM)
    for constraint in com.constraints
        if :in_all_different in fieldnames(typeof(constraint))
            if !constraint.in_all_different
                subscriptions_idxs =
                    [[i for i in com.subscription[v]] for v in constraint.indices]
                intersects = intersect(subscriptions_idxs...)

                for i in intersects
                    if isa(com.constraints[i].set, AllDifferentSet)
                        constraint.in_all_different = true
                        break
                    end
                end
            end
        end
    end
end

"""
    sort_solutions!(com::CS.CoM)

Order com.solutions by objective
"""
function sort_solutions!(com::CS.CoM)
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    sort!(com.solutions, by = s -> s.incumbent * obj_factor)
end

function print_info(com::CS.CoM)
    println("# Variables: ", length(com.search_space))
    println("# Constraints: ", length(com.constraints))
    for field in fieldnames(CS.NumberConstraintTypes)
        field_str = uppercasefirst(String(field))
        val = getfield(com.info.n_constraint_types, field)
        val != 0 && println(" - # $field_str: $val")
    end
    println()
end

"""
    solve!(com::CS.CoM, options::SolverOptions)

Solve the constraint model based on the given settings.
"""
function solve!(com::CS.CoM, options::SolverOptions)
    com.options = options
    backtrack = options.backtrack
    max_bt_steps = options.max_bt_steps
    backtrack_sorting = options.backtrack_sorting
    keep_logs = options.keep_logs
    com.traverse_strategy = get_traverse_strategy(;options = options)

    if :Info in com.options.logging
        print_info(com)
    end
    com.start_time = time()

    set_constraint_hashes!(com)

    # initialize constraints if `init_constraint!` exists for the constraint
    init_constraints!(com)

    com.input[:logs] = keep_logs
    if keep_logs
        com.init_search_space = deepcopy(com.search_space)
    end

    set_in_all_different!(com)

    # check for better constraints
    simplify!(com)

    # check if all feasible even if for example everything is fixed
    feasible = prune!(com; pre_backtrack = true, initial_check = true)

    if !feasible
        com.solve_time = time() - com.start_time
        return :Infeasible
    end
    if all(v -> isfixed(v), com.search_space)
        com.best_bound = get_best_bound(com, BacktrackObj(com))
        com.best_sol = com.best_bound
        com.solve_time = time() - com.start_time
        new_sol_obj = Solution(com.best_sol, CS.value.(com.search_space))
        push!(com.solutions, new_sol_obj)
        return :Solved
    end
    feasible = prune!(com; pre_backtrack = true)

    com.best_bound = get_best_bound(com, BacktrackObj(com))
    if keep_logs
        push!(com.logs, log_one_node(com, length(com.search_space), 1, 1))
    end

    if !feasible
        com.solve_time = time() - com.start_time
        return :Infeasible
    end

    if all(v -> isfixed(v), com.search_space)
        com.best_sol = com.best_bound
        com.solve_time = time() - com.start_time
        new_sol_obj = Solution(com.best_sol, CS.value.(com.search_space))
        push!(com.solutions, new_sol_obj)
        return :Solved
    end
    if backtrack
        com.info.backtracked = true
        status = backtrack!(com, max_bt_steps; sorting = backtrack_sorting)
        sort_solutions!(com)
        com.solve_time = time() - com.start_time
        return status
    else
        @info "Backtracking is turned off."
        com.solve_time = time() - com.start_time
        return :NotSolved
    end
end

"""
    solve!(com::Optimizer)

Solve the constraint model based on the given settings.
"""
function solve!(model::Optimizer)
    com = model.inner
    return solve!(com, model.options)
end

end # module

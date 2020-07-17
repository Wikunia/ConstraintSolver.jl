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
include("constraints/all_different.jl")
include("constraints/equal_to.jl")
include("constraints/less_than.jl")
include("constraints/svc.jl")
include("constraints/equal_set.jl")
include("constraints/not_equal.jl")
include("constraints/table.jl")
include("constraints/indicator.jl")
include("constraints/reified.jl")

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
        # only call if the function got initialized already
        if constraint.std.is_initialized
            feasible =
                still_feasible(com, constraint, constraint.std.fct, constraint.std.set, value, index)
            !feasible && break
        end
    end
    return feasible
end

"""
    set_pvals!(com::CS.CoM, constraint::Constraint)

Compute the possible values inside this constraint and set it as constraint.std.pvals
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
    constraint.std.pvals = pvals
    if constraint isa IndicatorConstraint || constraint isa ReifiedConstraint
        set_pvals!(com, constraint.inner_constraint)
    end
end

"""
    add_constraint!(com::CS.CoM, constraint::Constraint)

Add a constraint to the model i.e `add_constraint!(com, a != b)`
"""
function add_constraint!(com::CS.CoM, constraint::Constraint)
    @assert constraint.idx != 0
    push!(com.constraints, constraint)
    set_pvals!(com, constraint)
    for (i, ind) in enumerate(constraint.indices)
        push!(com.subscription[ind], constraint.idx)
    end
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
            if constraint_idxs_vec[ci] < best_open || com.constraints[ci].std.hash < best_hash
                best_ci = ci
                best_open = constraint_idxs_vec[ci]
                best_hash = com.constraints[ci].std.hash
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
            prune_constraint!(com, constraint, constraint.std.fct, constraint.std.set; logs = false)
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
            if constraint.std.impl.single_reverse_pruning
                single_reverse_pruning_constraint!(com, constraint, constraint.std.fct, constraint.std.set,
                                                    var, backtrack_idx)
            end
        end
    end
    for constraint in com.constraints
        if constraint.std.impl.reverse_pruning
            reverse_pruning_constraint!(com, constraint, constraint.std.fct, constraint.std.set, backtrack_idx)
        end
    end
    com.c_backtrack_idx = com.backtrack_vec[backtrack_idx].parent_idx
end

"""
    get_best_bound(com::CS.CoM, backtrack_obj::BacktrackObj; var_idx=0, lb=0, ub=0)

Return the best bound if setting the variable with idx: `var_idx` to 
    lb <= var[var_idx] <= ub if var_idx != 0
Without an objective function return 0.
"""
function get_best_bound(com::CS.CoM, backtrack_obj::BacktrackObj; var_idx = 0, lb = 0, ub = 0)
    if com.sense == MOI.FEASIBILITY_SENSE
        return zero(com.best_bound)
    end
    return get_best_bound(com, backtrack_obj, com.objective, var_idx, lb, ub)
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
            !isempty(prune_steps) && restore_prune!(com, prune_steps)
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

    !isempty(prune_steps) && restore_prune!(com, prune_steps)
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
        relevant = any(com.var_in_obj[i] for i in constraint.indices)
        if relevant
            feasible = prune_constraint!(
                com,
                constraint,
                constraint.std.fct,
                constraint.std.set;
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
    restore_prune!(com, backtrack_id)
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
    backtrack_vec::Vector{BacktrackObj{T}}, com::CS.CoM{T},num_backtrack_objs, parent_idx, depth, step_nr, ind; check_bound=false)

Create two branches with two additional BacktrackObj and add them to backtrack_vec 
"""
function add2backtrack_vec!(
    backtrack_vec::Vector{BacktrackObj{T}},
    com::CS.CoM{T},
    num_backtrack_objs,
    parent_idx,
    depth,
    step_nr,
    ind;
    check_bound = false,
) where {T<:Real}
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    left_lb, left_ub, right_lb, right_ub = get_split_pvals(com, com.branch_split, com.search_space[ind])

    #=
        Check whether the new node is needed which depends on
        - Is there a solution already? 
            - no => Add 
        - Do we want all solutions? 
            - yes => Add
        - Do we want all optimal solutions? 
            - yes => Add if better or same as previous optimal one
    =#

    # left branch
    num_backtrack_objs += 1
    backtrack_obj = BacktrackObj(
        num_backtrack_objs,
        parent_idx,
        depth,
        :Open,
        ind,
        left_lb,
        left_ub,
        backtrack_vec[parent_idx].best_bound, # initialize with parent best bound
        backtrack_vec[parent_idx].solution,
        zeros(length(com.search_space))
    )
    backtrack_obj.best_bound = get_best_bound(com, backtrack_obj; var_idx = ind, lb = left_lb, ub = left_ub)
    # only include nodes which have a better objective than the current best solution if one was found already
    if com.options.all_solutions || !check_bound || length(com.bt_solution_ids) == 0 ||
        backtrack_obj.best_bound * obj_factor < com.best_sol * obj_factor ||
        com.options.all_optimal_solutions && backtrack_obj.best_bound * obj_factor <= com.best_sol * obj_factor
    
        addBacktrackObj2Backtrack_vec!(
            backtrack_vec,
            backtrack_obj,
            com,
            num_backtrack_objs,
            -1,
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
        right_lb,
        right_ub,
        backtrack_vec[parent_idx].best_bound,
        backtrack_vec[parent_idx].solution,
        zeros(length(com.search_space))
    )
    backtrack_obj.best_bound = get_best_bound(com, backtrack_obj; var_idx = ind, lb = right_lb, ub = right_ub)
    if com.options.all_solutions || !check_bound || length(com.bt_solution_ids) == 0 ||
        backtrack_obj.best_bound * obj_factor < com.best_sol ||
        com.options.all_optimal_solutions && backtrack_obj.best_bound * obj_factor <= com.best_sol * obj_factor

        addBacktrackObj2Backtrack_vec!(
            backtrack_vec,
            backtrack_obj,
            com,
            num_backtrack_objs,
            -1,
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
    !remove_above!(com, com.search_space[ind], backtrack_obj.ub) && return false
    !remove_below!(com, com.search_space[ind], backtrack_obj.lb) && return false
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
        ind
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
            com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space)
        end
        # run at least once so that everything is well defined
        if step_nr > 2 && time() - com.start_time > com.options.time_limit
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
        if !set_bounds!(com, backtrack_obj) 
            com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space; feasible=false)
            continue
        end

        constraints = com.constraints[com.subscription[ind]]
        com.info.backtrack_fixes += 1

        further_pruning = true
        # first update the best bound (only constraints which have an index in the objective function)
        if com.sense != MOI.FEASIBILITY_SENSE
            feasible, further_pruning = update_best_bound!(backtrack_obj, com, constraints)
            if !feasible
                # need to call as some function might have pruned something.
                # Just need to be sure that we save the latest states
                call_finished_pruning!(com)
                com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space; feasible=false)
                com.info.backtrack_reverses += 1
                continue
            end
        end

        if further_pruning
            # prune completely start with all that changed by the fix or by updating best bound
            feasible = prune!(com)
            call_finished_pruning!(com)
            if !feasible
                com.info.backtrack_reverses += 1
                com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space; feasible=false)
                continue
            end
        else
            call_finished_pruning!(com)
        end

        if log_table
            last_table_row = update_table_log(com, backtrack_vec)
        end

        found, ind = get_next_branch_variable(com)
        # no index found => solution found
        if !found
            finished = add_new_solution!(com, backtrack_vec, backtrack_obj, log_table)
            if finished
                # close the previous backtrack object
                backtrack_vec[last_backtrack_id].status = :Closed
                com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space)
                return :Solved
            end
            continue
        end

        if com.info.backtrack_fixes > max_bt_steps
            backtrack_vec[last_backtrack_id].status = :Closed
            com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space)
            return :NotSolved
        end

        if com.input[:logs]
            com.logs[backtrack_obj.idx] =
                log_one_node(com, length(com.search_space), backtrack_obj.idx, step_nr)
        end

        leafs_best_bound = get_best_bound(com, backtrack_obj)
        
        last_backtrack_obj = backtrack_vec[last_backtrack_id]
        num_backtrack_objs = add2backtrack_vec!(
            backtrack_vec,
            com,
            num_backtrack_objs,
            last_backtrack_obj.idx,
            last_backtrack_obj.depth + 1,
            step_nr,
            ind;
            check_bound = true,
        )
    end
    backtrack_vec[last_backtrack_id].status = :Closed
    com.input[:logs] && log_node_state!(com.logs[last_backtrack_id], backtrack_vec[last_backtrack_id],  com.search_space)
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
Return a list of newly added constraint ids
"""
function simplify!(com)
    added_constraint_idxs = Int[]
    # check if we have all_different and sum constraints
    # (all different where every value is used)
    b_all_different = false
    b_all_different_sum = false
    b_eq_sum = false
    for constraint in com.constraints
        if isa(constraint.std.set, AllDifferentSetInternal)
            b_all_different = true
            if length(constraint.indices) == length(constraint.std.pvals)
                b_all_different_sum = true
            end
        elseif isa(constraint.std.fct, SAF) && isa(constraint.std.set, MOI.EqualTo)
            b_eq_sum = true
        end
    end
    if b_all_different_sum && b_eq_sum
        # for each all_different constraint
        # which has an implicit sum constraint
        # check which sum constraints are completely inside all different
        # which are partially inside
        # compute inside sum and total sum
        n_constraints_before = length(com.constraints)
        for constraint_idx = 1:length(com.constraints)
            constraint = com.constraints[constraint_idx]

            if isa(constraint.std.set, AllDifferentSetInternal)
                add_sum_constraint = true
                if length(constraint.indices) == length(constraint.std.pvals)
                    all_diff_sum = sum(constraint.std.pvals)
                    # check if some sum constraints are completely inside this alldifferent constraint
                    in_sum = 0
                    found_possible_constraint = false
                    outside_indices = constraint.indices
                    for sc_idx in constraint.sub_constraint_idxs
                        sub_constraint = com.constraints[sc_idx]
                        if isa(sub_constraint.std.fct, SAF) &&
                            isa(sub_constraint.std.set, MOI.EqualTo)
                            # the coefficients must be all 1
                            if all(t.coefficient == 1 for t in sub_constraint.std.fct.terms)
                                found_possible_constraint = true
                                in_sum += sub_constraint.std.set.value -
                                    sub_constraint.std.fct.constant
                                outside_indices = setdiff(outside_indices, sub_constraint.indices)
                            end
                        end
                    end
                    if found_possible_constraint && length(outside_indices) <= 4
                        # TODO: check for a better way of accessing the parameteric type of ConstraintSolverModel (also see below)
                        constraint_idx = length(com.constraints)+1
                        T = isapprox_discrete(com, all_diff_sum - in_sum) ? Int : Float64
                        lc =  LinearConstraint(constraint_idx, outside_indices, ones(Int, length(outside_indices)),
                        0, MOI.EqualTo{T}(all_diff_sum - in_sum))
                        add_constraint!(
                            com,
                            lc
                        )
                        push!(added_constraint_idxs, constraint_idx)
                    end

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
                            if isa(sub_constraint.std.fct, SAF) &&
                               isa(sub_constraint.std.set, MOI.EqualTo)
                                if all(t.coefficient == 1 for t in sub_constraint.std.fct.terms)
                                    found_sum_constraint = true
                                    total_sum +=
                                        sub_constraint.std.set.value -
                                        sub_constraint.std.fct.constant
                                    all_inside = true
                                    for sub_variable_idx in sub_constraint.indices
                                        if !haskey(cons_indices_dict, sub_variable_idx)
                                            all_inside = false
                                            push!(outside_indices, sub_variable_idx)
                                        else
                                            delete!(cons_indices_dict, sub_variable_idx)
                                        end
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
                    if add_sum_constraint && length(outside_indices) <= 4
                        constraint_idx = length(com.constraints)+1
                        T = isapprox_discrete(com, total_sum - all_diff_sum) ? Int : Float64
                        lc =  LinearConstraint(constraint_idx, outside_indices, ones(Int, length(outside_indices)),
                        0, MOI.EqualTo{T}(total_sum - all_diff_sum))
                        add_constraint!(
                            com,
                            lc
                        )
                        push!(added_constraint_idxs, constraint_idx)
                    end
                end
            end
        end
    end
    return added_constraint_idxs
end

"""
    set_in_all_different!(com::CS.CoM)

Set `constraint.in_all_different` if all variables in the constraint are part of the same `all_different` constraint.
"""
function set_in_all_different!(com::CS.CoM; constraints=com.constraints)
    for constraint in constraints
        if :in_all_different in fieldnames(typeof(constraint))
            if !constraint.in_all_different
                subscriptions_idxs =
                    [[i for i in com.subscription[v]] for v in constraint.indices]
                intersects = intersect(subscriptions_idxs...)

                for i in intersects
                    if isa(com.constraints[i].std.set, AllDifferentSetInternal)
                        constraint.in_all_different = true
                        push!(com.constraints[i].sub_constraint_idxs, constraint.idx)
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

function get_auto_traverse_strategy(com::CS.CoM)
    return com.sense == MOI.FEASIBILITY_SENSE ? :DFS : :BFS
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
    if options.traverse_strategy == :Auto
        options.traverse_strategy = get_auto_traverse_strategy(com)
    end
    com.traverse_strategy = get_traverse_strategy(;options = options)
    com.branch_split = get_branch_split(;options = options)

    set_impl_functions!(com)

    if :Info in com.options.logging
        print_info(com)
    end
    com.start_time = time()

    !set_init_fixes!(com) && return :Infeasible
    set_constraint_hashes!(com)
    set_in_all_different!(com)

    # initialize constraints if `init_constraint!` exists for the constraint
    !init_constraints!(com) && return :Infeasible

    com.input[:logs] = keep_logs
    if keep_logs
        com.init_search_space = deepcopy(com.search_space)
    end


    # check for better constraints
    added_con_idxs = simplify!(com)
    if length(added_con_idxs) > 0
        set_in_all_different!(com; constraints=com.constraints[added_con_idxs])
        set_constraint_hashes!(com; constraints=com.constraints[added_con_idxs])
        set_impl_functions!(com; constraints=com.constraints[added_con_idxs])
        !init_constraints!(com; constraints=com.constraints[added_con_idxs]) && return :Infeasible
    end

    options.no_prune && return :NotSolved

    # check if all feasible even if for example everything is fixed
    feasible = prune!(com; pre_backtrack = true, initial_check = true)
    # finished pruning will be called in second call a few lines down...

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
    call_finished_pruning!(com)

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
        if time() - com.start_time > com.options.time_limit 
            com.solve_time = time() - com.start_time
            return :Time
        end
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

module ConstraintSolver

using MatrixNetworks
using JSON
using MathOptInterface
using JuMP: @variable, @constraint, @objective, Model, optimizer_with_attributes, VariableRef, backend
import JuMP.sense_to_set

const MOI = MathOptInterface
const MOIU = MOI.Utilities

include("options.jl")

const CS = ConstraintSolver

mutable struct Variable
    idx                 :: Int
    lower_bound         :: Int # inital lower and
    upper_bound         :: Int # upper bound of the variable see min, max otherwise
    first_ptr           :: Int
    last_ptr            :: Int
    values              :: Vector{Int}
    indices             :: Vector{Int}
    offset              :: Int
    min                 :: Int # the minimum value during the solving process
    max                 :: Int # for initial see lower/upper_bound
    changes             :: Vector{Vector{Tuple{Symbol,Int,Int,Int}}}
    has_upper_bound     :: Bool # must be true to work
    has_lower_bound     :: Bool # must be true to work
    is_fixed            :: Bool
    is_integer          :: Bool # must be true to work
end

Variable(idx) = Variable(idx,0,0,0,0,[],[],0,0,0,Vector{Vector{Tuple{Symbol,Int,Int,Int}}}(), false, false, false, false)

mutable struct CSInfo
    pre_backtrack_calls :: Int
    backtracked         :: Bool
    backtrack_fixes     :: Int
    in_backtrack_calls  :: Int
    backtrack_reverses  :: Int
end

abstract type Constraint end

abstract type ObjectiveFunction end

mutable struct SingleVariableObjective <: ObjectiveFunction
    index   :: Int # index of the variable
    indices :: Vector{Int}
end


# used to designate a feasibility sense
struct NoObjective <: ObjectiveFunction end

mutable struct BasicConstraint <: Constraint
    idx                 :: Int
    fct                 :: Union{MOI.AbstractScalarFunction, MOI.AbstractVectorFunction}
    set                 :: Union{MOI.AbstractScalarSet, MOI.AbstractVectorSet}
    indices             :: Vector{Int}
    pvals               :: Vector{Int}
    check_in_best_bound :: Bool
    hash                :: UInt64
end

mutable struct MatchingInit
    l_in_len            :: Int
    matching_l          :: Vector{Int}
    matching_r          :: Vector{Int}
    index_l             :: Vector{Int}
    process_nodes       :: Vector{Int}
    depths              :: Vector{Int}
    parents             :: Vector{Int}
    used_l              :: Vector{Bool}
    used_r              :: Vector{Bool}
end

MatchingInit() = MatchingInit(0, Int[], Int[], Int[], Int[], Int[], Int[], Bool[], Bool[])

mutable struct AllDifferentConstraint <: Constraint
    idx                 :: Int
    fct                 :: Union{MOI.AbstractScalarFunction, MOI.AbstractVectorFunction}
    set                 :: Union{MOI.AbstractScalarSet, MOI.AbstractVectorSet}
    indices             :: Vector{Int}
    pvals               :: Vector{Int}
    pval_mapping        :: Vector{Int}
    vertex_mapping      :: Vector{Int}
    vertex_mapping_bw   :: Vector{Int}
    di_ei               :: Vector{Int}
    di_ej               :: Vector{Int}
    matching_init       :: MatchingInit
    check_in_best_bound :: Bool
    hash                :: UInt64
end

# support for a <= b constraint
mutable struct SingleVariableConstraint <: Constraint
    idx                 :: Int
    fct                 :: MOI.AbstractScalarFunction
    set                 :: MOI.AbstractScalarSet
    indices             :: Vector{Int}
    pvals               :: Vector{Int}
    lhs                 :: Int
    rhs                 :: Int
    check_in_best_bound :: Bool
    hash                :: UInt64
end

struct AllDifferentSet <: MOI.AbstractVectorSet
    dimension :: Int
end

struct EqualSet <: MOI.AbstractVectorSet
    dimension :: Int
end

struct NotEqualSet{T} <: MOI.AbstractScalarSet
    value :: T
end

mutable struct LinearCombination{T <: Real}
    indices             :: Vector{Int}
    coeffs              :: Vector{T}
end

mutable struct LinearConstraint{T <: Real} <: Constraint
    idx                 :: Int
    fct                 :: MOI.ScalarAffineFunction
    set                 :: MOI.AbstractScalarSet
    indices             :: Vector{Int}
    pvals               :: Vector{Int}
    in_all_different    :: Bool
    mins                :: Vector{T}
    maxs                :: Vector{T}
    pre_mins            :: Vector{T}
    pre_maxs            :: Vector{T}
    check_in_best_bound :: Bool
    hash                :: UInt64
end

mutable struct LinearCombinationObjective{T <: Real} <: ObjectiveFunction
    lc       :: LinearCombination{T}
    constant :: T
    indices  :: Vector{Int} # must exist to update the objective only if one of these changed
end

function LinearConstraint(fct::MOI.ScalarAffineFunction, set::MOI.AbstractScalarSet, indices::Vector{Int})
    # get common type for rhs and coeffs
    # use the first value (can be .upper, .lower, .value) and subtract left constant
    rhs = -fct.constant
    if isa(set, MOI.EqualTo)
        rhs += set.value
    end
    # TODO: for LessThan/GreaterThan
    coeffs = [t.coefficient for t in fct.terms]
    promote_T = promote_type(typeof(rhs), eltype(coeffs))
    if promote_T != eltype(coeffs)
        coeffs = convert.(promote_T, coeffs)
    end
    if promote_T != typeof(rhs)
        rhs = convert(promote_T, rhs)
    end
    maxs = zeros(promote_T, length(indices))
    mins = zeros(promote_T, length(indices))
    pre_maxs = zeros(promote_T, length(indices))
    pre_mins = zeros(promote_T, length(indices))
    # this can be changed later in `set_in_all_different!` but needs to be initialized with false
    in_all_different = false
    pvals = Int[]

    lc = LinearConstraint(
        0, # idx will be filled later
        fct,
        set,
        indices,
        pvals,
        in_all_different,
        mins,
        maxs,
        pre_mins,
        pre_maxs,
        false, # `check_in_best_bound` can be changed later but should be set to false by default
        zero(UInt64)
    )
    return lc
end

mutable struct BacktrackObj{T <: Real}
    idx                 :: Int
    parent_idx          :: Int
    depth               :: Int
    status              :: Symbol
    variable_idx        :: Int
    pval                :: Int
    best_bound          :: T
end

function Base.convert(::Type{B}, obj::BacktrackObj{T2}) where {T1, T2, B <: BacktrackObj{T1}}
    return BacktrackObj{T1}(
        obj.idx,
        obj.parent_idx,
        obj.depth,
        obj.status,
        obj.variable_idx,
        obj.pval,
        convert(T1, obj.best_bound)
    )
end

mutable struct TreeLogNode{T <: Real}
    id              :: Int
    status          :: Symbol
    best_bound      :: T
    step_nr         :: Int
    var_idx         :: Int
    set_val         :: Int
    var_states      :: Dict{Int,Vector{Int}}
    var_changes     :: Dict{Int,Vector{Tuple{Symbol, Int, Int, Int}}}
    children        :: Vector{TreeLogNode{T}}
end

mutable struct ConstraintSolverModel{T <: Real}
    init_search_space   :: Vector{Variable}
    search_space        :: Vector{Variable}
    subscription        :: Vector{Vector{Int}}
    constraints         :: Vector{Constraint}
    bt_infeasible       :: Vector{Int}
    c_backtrack_idx     :: Int
    backtrack_vec       :: Vector{BacktrackObj{T}}
    sense               :: MOI.OptimizationSense
    objective           :: ObjectiveFunction
    best_sol            :: T # Objective of the best solution
    best_bound          :: T # Overall best bound
    solutions           :: Vector{Int} # saves only the id to the BacktrackObj
    info                :: CSInfo
    input               :: Dict{Symbol,Any}
    logs                :: Vector{TreeLogNode{T}}
    options             :: SolverOptions
    start_time          :: Float64 
    solve_time          :: Float64 # seconds spend in solve
end

const CoM = ConstraintSolverModel

include("util.jl")
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
    ConstraintSolverModel(T::DataType=Float64)

Create the constraint model object and specify the type of the solution
"""
function ConstraintSolverModel(::Type{T}=Float64) where {T <: Real}
    ConstraintSolverModel(
        Vector{Variable}(), # init_search_space
        Vector{Variable}(), # search_space
        Vector{Vector{Int}}(), # subscription
        Vector{Constraint}(), # constraints
        Vector{Int}(), # bt_infeasible
        1, # c_backtrack_idx
        Vector{BacktrackObj{T}}(), # backtrack_vec
        MOI.FEASIBILITY_SENSE, #
        NoObjective(), #
        zero(T), # best_sol,
        zero(T), # best_bound
        Vector{Int}(), # save backtrack id to solution
        CSInfo(0, false, 0, 0, 0), # info
        Dict{Symbol,Any}(), # input
        Vector{TreeLogNode{T}}(), # logs
        SolverOptions(), # options,
        -1.0, # solve start time
        -1.0 # solve time will be overwritten
    )
end

@deprecate init() ConstraintSolverModel()

"""
    add_var!(com::CS.CoM, from::Int, to::Int; fix=nothing)

Adding a variable to the constraint model `com`. The variable is discrete and has the possible values from,..., to.
If the variable should be fixed to something one can use the `fix` keyword i.e `add_var!(com, 1, 9; fix=5)`
"""
function add_var!(com::CS.CoM, from::Int, to::Int; fix=nothing)
    ind = length(com.search_space)+1
    changes = Vector{Vector{Tuple{Symbol,Int,Int,Int}}}()
    push!(changes, Vector{Tuple{Symbol,Int,Int,Int}}())
    var = Variable(ind, from, to, 1, to-from+1, from:to, 1:to-from+1, 1-from, from, to, changes, true, true, fix !== nothing, true)
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
        feasible = still_feasible(com, constraint, constraint.fct, constraint.set, value, index)
        if !feasible
            break
        end
    end
    return feasible
end


"""
    fixed_vs_unfixed(search_space, indices)

Return the fixed_vals as well as the unfixed_indices
"""
function fixed_vs_unfixed(search_space, indices)
    # get all values which are fixed
    fixed_vals = Int[]
    unfixed_indices = Int[]
    for (i,ind) in enumerate(indices)
        if isfixed(search_space[ind])
            push!(fixed_vals, CS.value(search_space[ind]))
        else
            push!(unfixed_indices, i)
        end
    end
    return (fixed_vals, unfixed_indices)
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
    for (i,ind) in enumerate(indices)
        extra_from = variables[i].min
        extra_to   = variables[i].max
        comp_inside = false
        for cpvals in pvals_intervals
            if extra_from >= cpvals.from && extra_to <= cpvals.to
                # completely inside the interval already
                comp_inside = true
                break
            elseif extra_from >= cpvals.from && extra_from <= cpvals.to
                extra_from = cpvals.to+1
            elseif extra_to <= cpvals.to && extra_to >= cpvals.from
                extra_to = cpvals.from-1
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
    constraint.idx = length(com.constraints)+1
    push!(com.constraints, constraint)
    set_pvals!(com, constraint)
    for (i,ind) in enumerate(constraint.indices)
        push!(com.subscription[ind], constraint.idx)
    end
end

"""
    get_weak_ind(com::CS.CoM)

Get the next weak index for backtracking. This will be the next branching variable.
Return whether there is an unfixed variable and a best index
"""
function get_weak_ind(com::CS.CoM)
    lowest_num_pvals = typemax(Int)
    biggest_inf = -1
    best_ind = -1
    biggest_dependent = typemax(Int)
    found = false

    for ind in 1:length(com.search_space)
        if !isfixed(com.search_space[ind])
            num_pvals = nvalues(com.search_space[ind])
            inf = com.bt_infeasible[ind]
            if inf >= biggest_inf
                if inf > biggest_inf || num_pvals < lowest_num_pvals
                    lowest_num_pvals = num_pvals
                    biggest_inf = inf
                    best_ind = ind
                    found = true
                end
            end
        end
    end
    return found, best_ind
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
                    fix!(com, var, val; changes=false)
                elseif fct_symbol == :rm
                    rm!(com, var, val; changes=false)
                elseif fct_symbol == :remove_above
                    remove_above!(com, var, val; changes=false)
                elseif fct_symbol == :remove_below
                    remove_below!(com, var, val; changes=false)
                else
                    throw(ErrorException("There is no pruning function for $fct_symbol"))
                end
            end
        end
    end
end

function open_possibilities(search_space, indices)
    open = 0
    for vi in indices
        if !isfixed(search_space[vi])
            open += nvalues(search_space[vi])
        end
    end
    return open
end

function find_best_constraint(com::CS.CoM, constraint_idxs_vec)
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
function prune!(com::CS.CoM; pre_backtrack=false, all=false, only_once=false, initial_check=false)
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
                constraint_idxs_vec[inner_constraint.idx] = open_possibilities(search_space, inner_constraint.indices)
            end
        end
    end

    # while we haven't called every constraint
    while true
        b_open_constraint = false
        # will be changed or b_open_constraint => false
        open_pos, ci = find_best_constraint(com, constraint_idxs_vec)
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

        feasible = prune_constraint!(com, constraint, constraint.fct, constraint.set; logs = false)
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
                        if (only_once || initial_check) && constraint_idxs_vec[inner_constraint.idx] == N
                            continue
                        end
                        constraint_idxs_vec[inner_constraint.idx] = open_possibilities(search_space, inner_constraint.indices)
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
        l_ptr = max(1,var.last_ptr)

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
    get_best_bound(com::CS.CoM; var_idx=0, val=0)

Return the best bound if setting the variable with idx: `var_idx` to `val` if `var_idx != 0`.
Without an objective function return 0.
"""
function get_best_bound(com::CS.CoM; var_idx=0, val=0)
    if com.sense == MOI.FEASIBILITY_SENSE
        return zero(com.best_bound)
    end
    return get_best_bound(com, com.objective, var_idx, val)
end

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
            feasible = prune_constraint!(com, constraint, constraint.fct, constraint.set; logs = false)
            if !feasible
                return false, false
            end
        end
    end

    # check best_bound again
    # if best bound unchanged => continue pruning
    # otherwise try another path but don't close the current
    # -> means open new paths from here even if not pruned til the end
    new_bb = get_best_bound(com)
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

function update_best_bound!(com::CS.CoM)
    if com.sense == MOI.MIN_SENSE
        max_val = typemax(com.best_bound)
        com.best_bound = minimum([bo.status == :Open ? bo.best_bound : max_val for bo in com.backtrack_vec])
    elseif com.sense == MOI.MAX_SENSE
        min_val = typemin(com.best_bound)
        com.best_bound = maximum([bo.status == :Open ? bo.best_bound : min_val for bo in com.backtrack_vec])
    end # otherwise no update is needed
end

function set_state_to_best_sol!(com::CS.CoM, last_backtrack_id::Int)
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1
    backtrack_vec = com.backtrack_vec
    # find one of the best solutions
    sol, sol_id = findmin([backtrack_vec[sol_id].best_bound*obj_factor for sol_id in com.solutions])
    backtrack_id = com.solutions[sol_id]
    checkout_from_to!(com, last_backtrack_id, backtrack_id)
    # prune the last step as checkout_from_to! excludes the to part
    prune!(com, [backtrack_id])
end

"""
    backtrack!(com::CS.CoM, max_bt_steps; sorting=true)

Start backtracking and stop after `max_bt_steps`.
If `sorting` is set to `false` the same ordering is used as when used without objective this has only an effect when an objective is used.
Return :Solved or :Infeasible if proven or `:NotSolved` if interrupted by `max_bt_steps`.
"""
function backtrack!(com::CS.CoM, max_bt_steps; sorting=true)
    found, ind = get_weak_ind(com)
    com.info.backtrack_fixes   = 1

    pvals = reverse!(values(com.search_space[ind]))
    dummy_backtrack_obj = BacktrackObj(
        1, # idx
        0, # parent
        0, # depth
        :Close, # status
        0, # variable_idx
        0, # pval
        com.sense == MOI.MIN_SENSE ? typemax(com.best_bound) : typemin(com.best_bound)
    )

    backtrack_vec = com.backtrack_vec
    push!(backtrack_vec, dummy_backtrack_obj)

    # the first solve (before backtrack) has idx 1
    num_backtrack_objs = 1
    step_nr = 1
    for pval in pvals
        num_backtrack_objs += 1
        backtrack_obj = BacktrackObj(
            num_backtrack_objs,
            1,
            1,
            :Open,
            ind,
            pval,
            get_best_bound(com; var_idx=ind, val=pval)
        )
        push!(backtrack_vec, backtrack_obj)
        for v in com.search_space
            push!(v.changes, Vector{Tuple{Symbol,Int,Int,Int}}())
        end
        if com.input[:logs]
            push!(com.logs, log_one_node(com, length(com.search_space), num_backtrack_objs, -1))
        end
    end
    last_backtrack_id = 0

    started = true
    obj_factor = com.sense == MOI.MIN_SENSE ? 1 : -1

    while length(backtrack_vec) > 0
        step_nr += 1
        # get next open backtrack object
        l = 1

        # if there is no objective or sorting is set to false
        if com.sense == MOI.FEASIBILITY_SENSE || !sorting
            l = length(backtrack_vec)
            backtrack_obj = backtrack_vec[l]
            while backtrack_obj.status != :Open
                l -= 1
                if l == 0
                    break
                end
                backtrack_obj = backtrack_vec[l]
            end
        else # sort for objective
            # don't actually sort => just get the best backtrack idx
            # the one with the best bound and if same best bound choose the one with higher depth
            l = 0
            best_fac_bound = typemax(Int)
            best_depth = 0
            found_sol = length(com.solutions) > 0
            nopen_nodes = 0
            for i=1:length(backtrack_vec)
                bo = backtrack_vec[i]
                if bo.status == :Open
                    nopen_nodes += 1
                    if found_sol
                        if obj_factor*bo.best_bound < best_fac_bound || (obj_factor*bo.best_bound == best_fac_bound && bo.depth > best_depth)
                            l = i
                            best_depth = bo.depth
                            best_fac_bound = obj_factor*bo.best_bound
                        end
                    else
                        if bo.depth > best_depth || (obj_factor*bo.best_bound < best_fac_bound && bo.depth == best_depth)
                            l = i
                            best_depth = bo.depth
                            best_fac_bound = obj_factor*bo.best_bound
                        end
                    end
                end
            end

            if l != 0
                backtrack_obj = backtrack_vec[l]
            end
        end

        # no open node => Infeasible
        if l <= 0 || l > length(backtrack_vec)
            break
        end
        update_best_bound!(com)

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

        backtrack_obj.status = :Closed

        pval = backtrack_obj.pval

        # check if this value is still possible
        constraints = com.constraints[com.subscription[ind]]
        feasible = fulfills_constraints(com, ind, pval)
        if !feasible
            continue
        end
        # value is still possible => set it
        fix!(com, com.search_space[ind], pval)
        com.info.backtrack_fixes   += 1

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


        found, ind = get_weak_ind(com)
        # no index found => solution found
        if !found
            new_sol = get_best_bound(com)
            if length(com.solutions) == 0 || obj_factor*new_sol <= obj_factor*com.best_sol
                push!(com.solutions, backtrack_obj.idx)
                com.best_sol = new_sol
                if com.best_sol == com.best_bound
                    return :Solved
                end
                # set all nodes to :Worse if they can't achieve a better solution
                for bo in backtrack_vec
                    if bo.status == :Open && obj_factor*bo.best_bound >= com.best_sol
                        bo.status = :Worse
                    end
                end
                continue
            else
                if com.best_sol == com.best_bound
                    set_state_to_best_sol!(com, last_backtrack_id)
                    return :Solved
                end
                continue
            end
        end

        if com.info.backtrack_fixes > max_bt_steps
            return :NotSolved
        end

        if com.input[:logs]
            com.logs[backtrack_obj.idx] = log_one_node(com, length(com.search_space), backtrack_obj.idx, step_nr)
        end

        leafs_best_bound = get_best_bound(com)
        # if the objective can't get better we don't have to test all options
        if leafs_best_bound*obj_factor >= com.best_sol && length(com.solutions) > 0
            continue
        end

        pvals = reverse!(values(com.search_space[ind]))
        last_backtrack_obj = backtrack_vec[last_backtrack_id]
        for pval in pvals
            num_backtrack_objs += 1
            backtrack_obj = BacktrackObj(
                num_backtrack_objs, # idx
                last_backtrack_obj.idx, # parent
                last_backtrack_obj.depth + 1,
                :Open,
                ind,
                pval,
                get_best_bound(com; var_idx=ind, val=pval)
            )

            # only include nodes which have a better objective than the current best solution if one was found already
            if backtrack_obj.best_bound*obj_factor < com.best_sol || length(com.solutions) == 0
                push!(backtrack_vec, backtrack_obj)
                for v in com.search_space
                    push!(v.changes, Vector{Tuple{Symbol,Int,Int,Int}}())
                end
                if com.input[:logs]
                    push!(com.logs, log_one_node(com, length(com.search_space), num_backtrack_objs, -1))
                end
            else
                num_backtrack_objs -= 1
            end
        end
    end
    if length(com.solutions) > 0
        set_state_to_best_sol!(com, last_backtrack_id)
        return :Solved
    end
    return :Infeasible
end

function arr2dict(arr)
    d = Dict{Int,Bool}()
    for v in arr
        d[v] = true
    end
    return d
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
        for constraint_idx in 1:length(com.constraints)
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
                            if isa(sub_constraint.fct, SAF) && isa(sub_constraint.set, MOI.EqualTo)
                                if all(t.coefficient == 1 for t in sub_constraint.fct.terms)
                                    found_sum_constraint = true
                                    total_sum += sub_constraint.set.value-sub_constraint.fct.constant
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
                                        in_sum += sub_constraint.set.value-sub_constraint.fct.constant
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
                        add_constraint!(com, sum(com.search_space[outside_indices]) == total_sum - all_diff_sum)
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
                subscriptions_idxs = [[i for i in com.subscription[v]] for v in constraint.indices]
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
    solve!(com::CS.CoM, options::SolverOptions)

Solve the constraint model based on the given settings.
"""
function solve!(com::CS.CoM, options::SolverOptions)
    com.options = options
    backtrack = options.backtrack
    max_bt_steps = options.max_bt_steps
    backtrack_sorting = options.backtrack_sorting
    keep_logs = options.keep_logs

    com.start_time = time()

    set_constraint_hashes!(com)
    # sets check_in_best_bound per constraint if an objective function exists
    set_check_in_best_bound!(com)

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
    feasible = prune!(com; pre_backtrack=true, initial_check=true)

    if !feasible
        com.solve_time = time()-com.start_time
        return :Infeasible
    end
    if all(v->isfixed(v), com.search_space)
        com.best_bound = get_best_bound(com)
        com.best_sol = com.best_bound
        com.solve_time = time()-com.start_time
        return :Solved
    end
    feasible = prune!(com; pre_backtrack=true)

    com.best_bound = get_best_bound(com)
    if keep_logs
        push!(com.logs, log_one_node(com, length(com.search_space), 1, 1))
    end

    if !feasible
        com.solve_time = time()-com.start_time
        return :Infeasible
    end

    if all(v->isfixed(v), com.search_space)
        com.best_sol = com.best_bound
        com.solve_time = time()-com.start_time
        return :Solved
    end
    if backtrack
        com.info.backtracked = true
        status = backtrack!(com, max_bt_steps; sorting=backtrack_sorting)
        com.solve_time = time()-com.start_time
        return status
    else
        @info "Backtracking is turned off."
        com.solve_time = time()-com.start_time
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

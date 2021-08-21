"""
set_pvals!(model::CS.Optimizer)

Set the possible values for each constraint.
"""
function set_pvals!(model::CS.Optimizer)
    com = model.inner
    for constraint in com.constraints
        set_pvals!(com, constraint)
    end
end

"""
    set_var_in_all_different!(model::CS.Optimizer)

Set the vector `in_all_different` for each variable
"""
function set_var_in_all_different!(model::CS.Optimizer)
    com = model.inner
    n_all_different = com.info.n_constraint_types.alldifferent
    for var in com.search_space
        var.in_all_different = zeros(Bool, n_all_different)
    end
    ci = 1
    for constraint in com.constraints
        if constraint isa AllDifferentConstraint
            for vidx in constraint.indices
                com.search_space[vidx].in_all_different[ci] = true
            end
            ci += 1
        end
    end
end

"""
init_constraints!(com::CS.CoM; constraints=com.constraints)

Initializes all `constraints` which implement the `init_constraint!` method.
It also activates all constraints which implement the `activate_constraint!` method.
Return if feasible after initalization
"""
function init_constraints!(com::CS.CoM; constraints = com.constraints)
    feasible = true
    for constraint in constraints
        constraint.is_deactivated && continue
        feasible = init_constraint!(com, constraint, constraint.fct, constraint.set)
        !feasible && break
        constraint.is_initialized = true

        feasible = activate_constraint!(com, constraint, constraint.fct, constraint.set)
        !feasible && break
        constraint.is_activated = true
    end
    return feasible
end

"""
init_constraints!(com::CS.CoM; constraints=com.constraints)

Initializes all constraints of the model as new `constraints` were added.
Return if feasible after the update of the initalization
"""
function update_init_constraints!(com::CS.CoM; constraints = com.constraints)
    feasible = true
    for constraint in com.constraints
        feasible = update_init_constraint!(
            com,
            constraint,
            constraint.fct,
            constraint.set,
            constraints,
        )
        !feasible && break
    end
    return feasible
end

"""
call_finished_pruning!(com)

Call `finished_pruning_constraint!` for every constraint which implements that function as saved in `constraint.impl.finished_pruning`
"""
function call_finished_pruning!(com)
    for constraint in com.constraints
        finished_pruning_constraint!(com, constraint, constraint.fct, constraint.set)
    end
end

"""
call_restore_pruning!(com, prune_steps)

Call `call_restore_pruning!` for every constraint which implements that function as saved in `constraint.impl.restore_pruning`
"""
function call_restore_pruning!(com, prune_steps)
    for constraint in com.constraints
        restore_pruning_constraint!(
            com,
            constraint,
            constraint.fct,
            constraint.set,
            prune_steps,
        )
    end
end

"""
    count_unfixed(com, constraint::Constraint)

Count number of unfixed variables in the given Constraint
"""
function count_unfixed(com::CS.CoM, constraint::Constraint)
    count(!isfixed, com.search_space[i] for i in constraint.indices)
end

"""
    get_two_unfixed(com, constraint::Constraint)

Get two unfixed indices and local indices of a constraint. One should use
[`count_unfixed`](@ref) to make sure that there are exactly two unfixed indices.
"""
function get_two_unfixed(com::CS.CoM, constraint::Constraint)
    local_vidx_1 = 0
    vidx_1 = 0
    local_vidx_2 = 0
    vidx_2 = 0
    for local_i in 1:length(constraint.indices)
        var = com.search_space[constraint.indices[local_i]]
        if !isfixed(var)
            if local_vidx_1 == 0
                local_vidx_1 = local_i
                vidx_1 = var.idx
            else
                local_vidx_2 = local_i
                vidx_2 = var.idx
                break
            end
        end
    end
    return local_vidx_1, vidx_1, local_vidx_2, vidx_2
end

function init_constraint!(
    com::CS.CoM,
    constraint::Constraint,
    fct,
    set
)
    return true
end

function activate_constraint!(::CS.CoM, ::Constraint, fct, set)
    return true
end

function finished_pruning_constraint!(::CS.CoM, ::Constraint, fct, set)
    nothing
end

function reverse_pruning_constraint!(
    com::CoM,
    constraint::Constraint,
    fct,
    set,
    backtrack_id,
)
    nothing
end

function single_reverse_pruning_constraint!(
    ::CoM,
    ::Constraint,
    fct,
    set,
    variable,
    backtrack_idx,
)
    nothing
end

function restore_pruning_constraint!(
    ::CoM,
    ::Constraint,
    fct,
    set,
    prune_steps,
)
    nothing
end

function update_best_bound_constraint!(
    com::CS.CoM,
    constraint::Constraint,
    fct,
    set,
    vidx,
    lb,
    ub,
)
    return true
end

function update_init_constraint!(
    com::CS.CoM,
    constraint::Constraint,
    fct,
    set,
    constraints,
)
    return true
end

implements_activate(::Type{<:Constraint}, ::Type{<:Any}, ::Type{<:Any}) = false
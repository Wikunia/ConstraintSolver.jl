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

"""
    init_constraint!(
        com::CS.CoM,
        constraint::Constraint,
        fct,
        set
    )

Fallback for `init_constraint!`. 
This function needs to be implemented if the constraint needs to be initialized for example to check 
certain things only ones or initialize some data structures.
[`activate_constraint!`](@ref) needs to be used when variables should be pruned on initialization as `init_constraint!`
even gets called when the constraint itself isn't active i.e inside an `or` constraint.

Return whether the constraint is feasible or not. 
"""
function init_constraint!(
    com::CS.CoM,
    constraint::Constraint,
    fct,
    set
)
    return true
end

"""
    implements_activate(::Type{<:ConstraintType}, ::Type{<:FctType}, ::Type{<:SetType})

Fallback for `implements_activate`. 

Return whether [`activate_constraint!`](@ref) is implemented
"""
implements_activate(::Type{<:Constraint}, ::Type{<:Any}, ::Type{<:Any}) = false

"""
    activate_constraint!(::CS.CoM, ::Constraint, fct, set)

Fallback for `activate_constraint!`. 
If this gets implemented please also implement [`implements_activate`](@ref).

This function will get called if the constraint gets activated by an indicator or reifed constraint as an example.
Can be used to prune variables that aren't possible without fixing anything further simply by being active.

Return whether the constraint is feasible.
"""
function activate_constraint!(::CS.CoM, ::Constraint, fct, set)
    return true
end

"""
    finished_pruning_constraint!(::CS.CoM, ::Constraint, fct, set)

Fallback for `finished_pruning_constraint!`. 
This function will get called after all pruning steps in one node. 
Can be used to change some data structure but no further pruning should be done here.

Return `nothing`
"""
function finished_pruning_constraint!(::CS.CoM, ::Constraint, fct, set)
    nothing
end

"""
    reverse_pruning_constraint!(::CS.CoM, ::Constraint, fct, set, backtrack_id)

Call [`_reverse_pruning_constraint!`](@ref) if the constraint is activated
"""
function reverse_pruning_constraint!(
    com::CoM,
    constraint::Constraint,
    fct,
    set,
    backtrack_id,
)
    constraint.is_deactivated || _reverse_pruning_constraint!(com, constraint, fct, set, backtrack_id)
end

"""
    single_reverse_pruning_constraint!(::CS.CoM, ::Constraint, fct, set, variable, backtrack_id)

Call [`_single_reverse_pruning_constraint!`](@ref) if the constraint is activated
"""
function single_reverse_pruning_constraint!(
    com::CoM,
    constraint::Constraint,
    fct,
    set,
    variable,
    backtrack_id,
)
    constraint.is_deactivated || _single_reverse_pruning_constraint!(com, constraint, fct, set, variable, backtrack_id)
end

"""
    _reverse_pruning_constraint!(::CS.CoM, ::Constraint, fct, set, backtrack_id)

Fallback for `reverse_pruning_constraint!`. 
This function will get called when a specific pruning step with id `backtrack_id` needs to get reversed.
Should only be implemented when the data structure of the constraint needs to be updated. 
All variables are updated automatically anyway.
See also [`single_reverse_pruning_constraint!`](@ref) to change the data structure based on a single variable.

Return `nothing`
"""
function _reverse_pruning_constraint!(
    com::CoM,
    constraint::Constraint,
    fct,
    set,
    backtrack_id,
)
    nothing
end

"""
    _single_reverse_pruning_constraint!(::CS.CoM, ::Constraint, fct, set, variable, backtrack_id)

Fallback for `_single_reverse_pruning_constraint!`. 
This function will get called when a specific pruning step with id `backtrack_id` needs to get reversed.
In contrast to [`reverse_pruning_constraint!`](@ref) however this function will be called for each variable individually and is called 
before [`reverse_pruning_constraint!`](@ref).
Should only be implemented when the data structure of the constraint needs to be updated. 
All variables are updated automatically anyway.

Return `nothing`
"""
function _single_reverse_pruning_constraint!(
    ::CoM,
    ::Constraint,
    fct,
    set,
    variable,
    backtrack_id,
)
    nothing
end

"""
    restore_pruning_constraint!(::CS.CoM, ::Constraint, fct, set, prune_steps)

Fallback for `restore_pruning_constraint!`. 
This function will get called when pruning steps will be restored. `prune_steps` is a vector.
If the data structure of the constraint needs to be updated to reflect the data it had at the last `prune_step` this function needs 
to be implemented.

Return `nothing`
"""
function restore_pruning_constraint!(
    ::CoM,
    ::Constraint,
    fct,
    set,
    prune_steps,
)
    nothing
end

"""
    update_best_bound_constraint!(::CS.CoM, ::Constraint, fct, set, vidx, lb, ub)

Fallback for `update_best_bound_constraint!`. 
This function will get called when a new objective bound gets computed.
If the constraint needs to change variables inside the underlying LP this function should be used to update those variables.

Return `nothing`
"""
function update_best_bound_constraint!(
    com::CS.CoM,
    constraint::Constraint,
    fct,
    set,
    vidx,
    lb,
    ub,
)
    nothing
end

"""
update_init_constraint!(::CS.CoM, ::Constraint, fct, set, constraints)

Fallback for `update_init_constraint!`. 
This function is called when new constraints are added due to presolve processes. 
It gets called with all new constraints. 
Normally it shouldn't be necessary to implement as constraints should be independent of each other.
Sometimes however this seems to make sense :D 

Return whether the constraint is feasible.
"""
function update_init_constraint!(
    com::CS.CoM,
    constraint::Constraint,
    fct,
    set,
    constraints,
)
    return true
end


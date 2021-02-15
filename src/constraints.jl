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

Initializes all `constraints` which implement the `init_constraint!` function.
Return if feasible after initalization
"""
function init_constraints!(com::CS.CoM; constraints = com.constraints)
    feasible = true
    for constraint in constraints
        if constraint.impl.init
            feasible = init_constraint!(com, constraint, constraint.fct, constraint.set)
            !feasible && break
        end
        constraint.is_initialized = true
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
        if constraint.impl.update_init
            feasible = update_init_constraint!(
                com,
                constraint,
                constraint.fct,
                constraint.set,
                constraints,
            )
            !feasible && break
        end
    end
    return feasible
end

"""
set_impl_functions!(com, constraint::Constraint)

Set std.impl.[] for each constraint
"""
function set_impl_functions!(com, constraint::Constraint)
    constraint.is_deactivated && return
    if com.sense != MOI.FEASIBILITY_SENSE
        set_impl_update_best_bound!(constraint)
    end
    set_impl_init!(constraint)
    set_impl_update_init!(constraint)
    set_impl_finished_pruning!(constraint)
    set_impl_restore_pruning!(constraint)
    set_impl_reverse_pruning!(constraint)
end

"""
set_impl_functions!(com::CS.CoM)

Set std.impl.[] for each constraint
"""
function set_impl_functions!(com::CS.CoM; constraints = com.constraints)
    for constraint in constraints
        set_impl_functions!(com, constraint)
    end
end

"""
set_impl_init!(constraint::Constraint)
Sets `std.impl.init` if the constraint type has a `init_constraint!` method
"""
function set_impl_init!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(init_constraint!, (CS.CoM, c_type, c_fct_type, c_set_type))
        constraint.impl.init = true
    end
end

"""
set_impl_update_init!(constraint::Constraint)
Sets `std.impl.update_init` if the constraint type has a `update_init_constraint!` method
"""
function set_impl_update_init!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(
        update_init_constraint!,
        (CS.CoM, c_type, c_fct_type, c_set_type, Vector{<:Constraint}),
    )
        constraint.impl.update_init = true
    end
end

"""
set_impl_update_best_bound!(constraint::Constraint)

Sets `update_best_bound` if the constraint type has a `update_best_bound_constraint!` method
"""
function set_impl_update_best_bound!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(
        update_best_bound_constraint!,
        (CS.CoM, c_type, c_fct_type, c_set_type, Int, Int, Int),
    )
        constraint.impl.update_best_bound = true
    else # just to be sure => set it to false otherwise
        constraint.impl.update_best_bound = false
    end
end

"""
set_impl_reverse_pruning!(constraint::Constraint)
Sets `std.impl.single_reverse_pruning` and `std.impl.reverse_pruning`
if `single_reverse_pruning_constraint!`, `reverse_pruning_constraint!` are implemented for `constraint`.
"""
function set_impl_reverse_pruning!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(
        single_reverse_pruning_constraint!,
        (CS.CoM, c_type, c_fct_type, c_set_type, CS.Variable, Int),
    )
        constraint.impl.single_reverse_pruning = true
    else # just to be sure => set it to false otherwise
        constraint.impl.single_reverse_pruning = false
    end

    if hasmethod(reverse_pruning_constraint!, (CS.CoM, c_type, c_fct_type, c_set_type, Int))
        constraint.impl.reverse_pruning = true
    else # just to be sure => set it to false otherwise
        constraint.impl.reverse_pruning = false
    end
end

"""
set_impl_finished_pruning!(constraint::Constraint)
Sets `std.impl.finished_pruning` if `finished_pruning_constraint!`  is implemented for `constraint`.
"""
function set_impl_finished_pruning!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(finished_pruning_constraint!, (CS.CoM, c_type, c_fct_type, c_set_type))
        constraint.impl.finished_pruning = true
    else # just to be sure => set it to false otherwise
        constraint.impl.finished_pruning = false
    end
end

"""
set_impl_restore_pruning!(constraint::Constraint)
Sets `std.impl.restore_pruning` if `restore_pruning_constraint!`  is implemented for the `constraint`.
"""
function set_impl_restore_pruning!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(
        restore_pruning_constraint!,
        (CS.CoM, c_type, c_fct_type, c_set_type, Union{Int,Vector{Int}}),
    )
        constraint.impl.restore_pruning = true
    else # just to be sure => set it to false otherwise
        constraint.impl.restore_pruning = false
    end
end

"""
call_finished_pruning!(com)

Call `finished_pruning_constraint!` for every constraint which implements that function as saved in `constraint.impl.finished_pruning`
"""
function call_finished_pruning!(com)
    for constraint in com.constraints
        if constraint.impl.finished_pruning
            finished_pruning_constraint!(com, constraint, constraint.fct, constraint.set)
        end
    end
end

"""
call_restore_pruning!(com, prune_steps)

Call `call_restore_pruning!` for every constraint which implements that function as saved in `constraint.impl.restore_pruning`
"""
function call_restore_pruning!(com, prune_steps)
    for constraint in com.constraints
        if constraint.impl.restore_pruning
            restore_pruning_constraint!(
                com,
                constraint,
                constraint.fct,
                constraint.set,
                prune_steps,
            )
        end
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

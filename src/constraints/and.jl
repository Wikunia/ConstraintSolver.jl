function init_constraint!(
    com::CS.CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet;
)
    set_impl_functions!(com, constraint.lhs)
    set_impl_functions!(com, constraint.rhs)
    if constraint.lhs.impl.init   
        !init_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set) && return false
    end
    if constraint.rhs.impl.init   
        !init_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set) && return false
    end
    return true
end

"""
    is_constraint_solved(
        constraint::AndConstraint,
        fct,
        set::AndSet,
        values::Vector{Int},
    )  

Checks if both inner constraints are solved
"""
function is_constraint_solved(
    constraint::AndConstraint,
    fct,
    set::AndSet,
    values::Vector{Int},
)
    lhs_num_vars = get_num_vars(constraint.lhs.fct)
    lhs_solved = is_constraint_solved(constraint.lhs, constraint.lhs.fct, constraint.lhs.set, values[1:lhs_num_vars])
    !lhs_solved && return false
    rhs_num_vars = get_num_vars(constraint.rhs.fct)
    rhs_solved = is_constraint_solved(constraint.rhs, constraint.rhs.fct, constraint.rhs.set, values[end-rhs_num_vars+1:end])
    return rhs_solved
end

"""
    function is_constraint_violated(
        com::CoM,
        constraint::AndConstraint,
        fct,
        set::AndSet,
    )

Check if either of the inner constraints are violated already
"""
function is_constraint_violated(
    com::CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet,
)
    lhs_violated = is_constraint_violated(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    lhs_violated && return true
    rhs_violated = is_constraint_violated(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    return lhs_violated || rhs_violated
end


"""
    still_feasible(com::CoM, constraint::AndConstraint, fct, set::AndSet, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `vidx` to `value`.
**Attention:** This assumes that it isn't violated before.
"""
function still_feasible(
    com::CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet,
    vidx::Int,
    value::Int,
)
    lhs_indices = constraint.lhs.indices
    for i in 1:length(lhs_indices)
        if lhs_indices[i] == vidx
            !still_feasible(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set, vidx, value) && return false
        end
    end
    rhs_indices = constraint.rhs.indices
    for i in 1:length(rhs_indices)
        if rhs_indices[i] == vidx
            !still_feasible(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set, vidx, value) && return false
        end
    end
    return true
end

"""
    prune_constraint!(com::CS.CoM, constraint::AndConstraint, fct, set::AndSet; logs = true)

Reduce the number of possibilities given the `AndConstraint` by pruning both parts
Return whether still feasible
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet;
    logs = true,
)
    activate_lhs!(com, constraint)
    !prune_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set; logs=logs) && return false
    activate_rhs!(com, constraint)
    feasible = prune_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set; logs=logs)
    return feasible
end
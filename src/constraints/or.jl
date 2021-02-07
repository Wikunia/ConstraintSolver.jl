function init_constraint!(
    com::CS.CoM,
    constraint::OrConstraint,
    fct,
    set::OrSet;
    active = true,
)
    set_impl_functions!(com,  constraint.lhs)
    set_impl_functions!(com,  constraint.rhs)
    !active && return true
    lhs_feasible = true
    if constraint.lhs.impl.init   
        lhs_feasible = init_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    end
    rhs_feasible = true
    if constraint.rhs.impl.init   
        rhs_feasible = init_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    end
    return lhs_feasible || rhs_feasible
end

"""
    is_constraint_solved(
        constraint::OrConstraint,
        fct,
        set::OrSet,
        values::Vector{Int},
    )  

Checks if at least one of the inner constraints is solved
"""
function is_constraint_solved(
    constraint::OrConstraint,
    fct,
    set::OrSet,
    values::Vector{Int},
)
    lhs_num_vars = get_num_vars(constraint.lhs.fct)
    lhs_solved = is_constraint_solved(constraint.lhs, constraint.lhs.fct, constraint.lhs.set, values[1:lhs_num_vars])
    rhs_num_vars = get_num_vars(constraint.rhs.fct)
    rhs_solved = is_constraint_solved(constraint.rhs, constraint.rhs.fct, constraint.rhs.set, values[end-rhs_num_vars+1:end])
    return lhs_solved || rhs_solved
end

"""
    function is_constraint_violated(
        com::CoM,
        constraint::OrConstraint,
        fct,
        set::OrSet,
    )

Check if both inner constraints are violated already
"""
function is_constraint_violated(
    com::CoM,
    constraint::OrConstraint,
    fct,
    set::OrSet,
)
    lhs_violated = is_constraint_violated(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    rhs_violated = is_constraint_violated(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    return lhs_violated && rhs_violated
end


"""
    still_feasible(com::CoM, constraint::OrConstraint, fct, set::OrSet, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `vidx` to `value`.
**Attention:** This assumes that it isn't violated before.
"""
function still_feasible(
    com::CoM,
    constraint::OrConstraint,
    fct,
    set::OrSet,
    vidx::Int,
    value::Int,
)
    lhs_feasible = true
    lhs_indices = constraint.lhs.indices
    for i in 1:length(lhs_indices)
        if lhs_indices[i] == vidx
            lhs_feasible = still_feasible(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set, vidx, value)
        end
    end
    rhs_feasible = true
    rhs_indices = constraint.rhs.indices
    for i in 1:length(rhs_indices)
        if rhs_indices[i] == vidx
            rhs_feasible = !still_feasible(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set, vidx, value) 
        end
    end
    return rhs_feasible || lhs_feasible
end

"""
    prune_constraint!(com::CS.CoM, constraint::OrConstraint, fct, set::OrSet; logs = true)

Reduce the number of possibilities given the `OrConstraint` by pruning both parts
Return whether still feasible
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::OrConstraint,
    fct,
    set::OrSet;
    logs = true,
)
    lhs_violated = is_constraint_violated(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    rhs_violated = is_constraint_violated(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    if lhs_violated && rhs_violated
        return false
    end
    if lhs_violated
        return prune_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set; logs=logs)
    end
    if rhs_violated
        return prune_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set; logs=logs)
    end
    return true
end
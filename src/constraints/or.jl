"""
    function is_constraint_violated(
        com::CoM,
        constraint::BoolConstraint,
        fct,
        set::OrSet,
    )

Check if both of the inner constraints are violated
"""
function is_constraint_violated(
    com::CoM,
    constraint::BoolConstraint,
    fct,
    set::OrSet,
)
    return is_lhs_constraint_violated(com, constraint) && is_rhs_constraint_violated(com, constraint) 
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
    lhs_feasible = !is_constraint_violated(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    if lhs_feasible
        lhs_indices = constraint.lhs.indices
        for i in 1:length(lhs_indices)
            if lhs_indices[i] == vidx
                lhs_feasible = still_feasible(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set, vidx, value)
                lhs_feasible && return true
                break
            end
        end
    end
    rhs_feasible = !is_constraint_violated(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    if rhs_feasible
        rhs_indices = constraint.rhs.indices
        for i in 1:length(rhs_indices)
            if rhs_indices[i] == vidx
                rhs_feasible = still_feasible(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set, vidx, value) 
                rhs_feasible && return true
                break
            end
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
        activate_rhs!(com, constraint)
        return prune_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set; logs=logs)
    end
    if rhs_violated
        activate_lhs!(com, constraint)
        return prune_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set; logs=logs)
    end
    return true
end
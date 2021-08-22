"""
    function _is_constraint_violated(
        com::CoM,
        constraint::BoolConstraint,
        fct,
        set::AndSet,
    )

Check if one of the inner constraints is violated
"""
function _is_constraint_violated(
    com::CoM,
    constraint::BoolConstraint,
    fct,
    set::AndSet,
)
    return is_lhs_constraint_violated(com, constraint) || is_rhs_constraint_violated(com, constraint) 
end

"""
    _still_feasible(com::CoM, constraint::AndConstraint, fct, set::AndSet, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `vidx` to `value`.
**Attention:** This assumes that it isn't violated before.
"""
function _still_feasible(
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
            !still_feasible(com, constraint.lhs, vidx, value) && return false
        end
    end
    rhs_indices = constraint.rhs.indices
    for i in 1:length(rhs_indices)
        if rhs_indices[i] == vidx
            !still_feasible(com, constraint.rhs, vidx, value) && return false
        end
    end
    return true
end

"""
    _prune_constraint!(com::CS.CoM, constraint::AndConstraint, fct, set::AndSet; logs = false)

Reduce the number of possibilities given the `AndConstraint` by pruning both parts
Return whether still feasible
"""
function _prune_constraint!(
    com::CS.CoM,
    constraint::AndConstraint,
    fct,
    set::AndSet;
    logs = false,
)
    !activate_lhs!(com, constraint) && return false
    !prune_constraint!(com, constraint.lhs; logs=logs) && return false
    !activate_rhs!(com, constraint) && return false
    feasible = prune_constraint!(com, constraint.rhs; logs=logs)
    return feasible
end
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
            if !still_feasible(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set, vidx, value) 
                return false
            end
        end
    end
    rhs_indices = constraint.rhs.indices
    for i in 1:length(rhs_indices)
        if rhs_indices[i] == vidx
            if !still_feasible(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set, vidx, value) 
                return false
            end
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
    !activate_lhs!(com, constraint) && return false
    !prune_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set; logs=logs) && return false
    !activate_rhs!(com, constraint) && return false
    feasible = prune_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set; logs=logs)
    return feasible
end
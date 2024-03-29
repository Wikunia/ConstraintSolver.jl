function init_constraint!(
    com::CS.CoM,
    constraint::XorConstraint,
    fct,
    set::XorSet;
)
    !init_lhs_and_rhs!(com, constraint, fct, set) && return false

    if constraint.complement_lhs !== nothing 
        init_constraint!(com, constraint.complement_lhs, constraint.complement_lhs.fct, constraint.complement_lhs.set)
    end
    if constraint.complement_rhs !== nothing
        init_constraint!(com, constraint.complement_rhs, constraint.complement_rhs.fct, constraint.complement_rhs.set)
    end
    return true
end

"""
    function is_constraint_violated(
        com::CoM,
        constraint::BoolConstraint,
        fct,
        set::XorSet,
    )

Check if both of the inner constraints are violated or whether both are solved
"""
function is_constraint_violated(
    com::CoM,
    constraint::BoolConstraint,
    fct,
    set::XorSet,
)
    both_violated = is_lhs_constraint_violated(com, constraint) && is_rhs_constraint_violated(com, constraint) 
    both_violated && return true
    lhs_solved = is_constraint_solved(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    rhs_solved = is_constraint_solved(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    return lhs_solved && rhs_solved
end

"""
    still_feasible(com::CoM, constraint::XorConstraint, fct, set::XorSet, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `vidx` to `value`.
**Attention:** This assumes that it isn't violated before.
"""
function still_feasible(
    com::CoM,
    constraint::XorConstraint,
    fct,
    set::XorSet,
    vidx::Int,
    value::Int,
)
    lhs_violated = is_constraint_violated(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    lhs_feasible = !lhs_violated
    lhs_solved = false
    if lhs_feasible
        lhs_solved = is_constraint_solved_when_fixed(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set, vidx, value)
    end
    if lhs_feasible && !lhs_solved
        lhs_indices = constraint.lhs.indices
        for i in 1:length(lhs_indices)
            if lhs_indices[i] == vidx
                lhs_feasible = still_feasible(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set, vidx, value)
                break
            end
        end
    end
    rhs_violated = is_constraint_violated(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    rhs_feasible = !rhs_violated
    rhs_solved = false
    if rhs_feasible
        rhs_solved = is_constraint_solved_when_fixed(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set, vidx, value)
    end
    if rhs_feasible && !rhs_solved
        rhs_indices = constraint.rhs.indices
        for i in 1:length(rhs_indices)
            if rhs_indices[i] == vidx
                rhs_feasible = still_feasible(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set, vidx, value) 
                break
            end
        end
    end

    # at least one must be feasible
    if !lhs_feasible
        return rhs_feasible
    elseif !rhs_feasible
        return lhs_feasible
    end
    # not allowed that both are already solved
    return !(lhs_solved && rhs_solved)
end

"""
    prune_constraint!(com::CS.CoM, constraint::XorConstraint, fct, set::XorSet; logs = true)

Reduce the number of possibilities given the `XorConstraint` by pruning both parts
Return whether still feasible
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::XorConstraint,
    fct,
    set::XorSet;
    logs = true,
)
    lhs_violated = is_constraint_violated(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    rhs_violated = is_constraint_violated(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    if lhs_violated && rhs_violated
        return false
    end
    # check if one is already solved
    lhs_solved = is_constraint_solved(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    rhs_solved = is_constraint_solved(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    if lhs_solved && rhs_solved
        return false
    end

    # if one is solved => complement prune the other
    # Todo implement for activated complement constraints
    if lhs_solved && constraint.complement_rhs !== nothing
        return prune_constraint!(com, constraint.complement_rhs, constraint.complement_rhs.fct, constraint.complement_rhs.set; logs=logs)
    end
    if rhs_solved && constraint.complement_lhs !== nothing
        return prune_constraint!(com, constraint.complement_lhs, constraint.complement_lhs.fct, constraint.complement_lhs.set; logs=logs)
    end

    # if both aren't solved yet we only prune if one is violated
    if !lhs_solved && !rhs_solved
        if lhs_violated
            activate_rhs!(com, constraint)
            return prune_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set; logs=logs)
        end
        if rhs_violated
            activate_lhs!(com, constraint)
            return prune_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set; logs=logs)
        end
    end
   
    return true
end
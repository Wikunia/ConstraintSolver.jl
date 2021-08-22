function set_first_node_call!(constraint::XNorConstraint, val::Bool)
    constraint.first_node_call = val
    set_first_node_call!(constraint.lhs, val)
    set_first_node_call!(constraint.rhs, val)
    if constraint.complement_lhs !== nothing
        constraint.complement_lhs.first_node_call = val
        set_first_node_call!(constraint.complement_lhs, val)
    end
    if constraint.complement_rhs !== nothing
        set_first_node_call!(constraint.complement_rhs, val)
    end
end

function init_constraint!(
    com::CS.CoM,
    constraint::XNorConstraint,
    fct,
    set::XNorSet;
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
    function _is_constraint_violated(
        com::CoM,
        constraint::BoolConstraint,
        fct,
        set::XNorSet,
    )

Check whether one side is solved and other is violated
"""
function _is_constraint_violated(
    com::CoM,
    constraint::BoolConstraint,
    fct,
    set::XNorSet,
)
    lhs_solved = is_constraint_solved(com, constraint.lhs)
    rhs_solved = is_constraint_solved(com, constraint.rhs)
    # neither of them is solved => it's not violated yet
    if !lhs_solved && !rhs_solved 
        return false
    end
    if lhs_solved && rhs_solved
        return false
    end

    lhs_violated = is_lhs_constraint_violated(com, constraint) 
    rhs_violated = is_rhs_constraint_violated(com, constraint) 
    if lhs_solved && rhs_violated
        return true
    end
    if rhs_solved && lhs_violated
        return true
    end

    return false
end

"""
    _still_feasible(com::CoM, constraint::XNorConstraint, fct, set::XNorSet, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `vidx` to `value`.
**Attention:** This assumes that it isn't violated before.
"""
function _still_feasible(
    com::CoM,
    constraint::XNorConstraint,
    fct,
    set::XNorSet,
    vidx::Int,
    value::Int,
)
    lhs_violated = is_constraint_violated(com, constraint.lhs)
    lhs_feasible = !lhs_violated
    lhs_solved = false
    if lhs_feasible
        lhs_solved = is_constraint_solved_when_fixed(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set, vidx, value)
    end
    if lhs_feasible && !lhs_solved
        lhs_indices = constraint.lhs.indices
        for i in 1:length(lhs_indices)
            if lhs_indices[i] == vidx
                lhs_feasible = still_feasible(com, constraint.lhs, vidx, value)
                break
            end
        end
    end
    rhs_violated = is_constraint_violated(com, constraint.rhs)
    rhs_feasible = !rhs_violated
    rhs_solved = false
    if rhs_feasible
        rhs_solved = is_constraint_solved_when_fixed(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set, vidx, value)
    end
    # both must be violated or both must be solved in the end
    if !lhs_feasible && rhs_solved
        return false
    end
    if rhs_feasible && !rhs_solved
        rhs_indices = constraint.rhs.indices
        for i in 1:length(rhs_indices)
            if rhs_indices[i] == vidx
                rhs_feasible = still_feasible(com, constraint.rhs, vidx, value) 
                break
            end
        end
    end

    if !rhs_feasible && lhs_solved
        return false
    end
    return true
end

"""
    _prune_constraint!(com::CS.CoM, constraint::XNorConstraint, fct, set::XNorSet; logs = false)

Reduce the number of possibilities given the `XNorConstraint` by pruning both parts
Return whether still feasible
"""
function _prune_constraint!(
    com::CS.CoM,
    constraint::XNorConstraint,
    fct,
    set::XNorSet;
    logs = false,
)
    lhs_violated = is_constraint_violated(com, constraint.lhs)
    rhs_violated = is_constraint_violated(com, constraint.rhs)
    if lhs_violated && rhs_violated
        return true
    end
    # check if one is already solved
    lhs_solved = is_constraint_solved(com, constraint.lhs)
    rhs_solved = is_constraint_solved(com, constraint.rhs)
    if lhs_solved && rhs_solved
        return true
    end

    # if one is solved => prune the other
    if lhs_solved
        activate_rhs!(com, constraint)
        return prune_constraint!(com, constraint.rhs; logs=logs)
    end
    if rhs_solved
        activate_lhs!(com, constraint)
        return prune_constraint!(com, constraint.lhs; logs=logs)
    end


    # if one is violated complement prune the other
    # Todo implement for activated complement constraints
    if lhs_violated && constraint.complement_rhs !== nothing && !implements_activate(typeof(constraint.complement_rhs), typeof(constraint.complement_rhs.fct), typeof(constraint.complement_rhs.set))
        return prune_constraint!(com, constraint.complement_rhs; logs=logs)
    end
    if rhs_violated && constraint.complement_lhs !== nothing && !implements_activate(typeof(constraint.complement_lhs), typeof(constraint.complement_lhs.fct), typeof(constraint.complement_lhs.set))
        return prune_constraint!(com, constraint.complement_lhs; logs=logs)
    end
   
    return true
end
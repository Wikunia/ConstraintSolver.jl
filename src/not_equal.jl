
function Base.:!(bc::CS.BasicConstraint)
    if bc.fct != equal
        throw("!BasicConstraint is only implemented for !equal")
    end
    if length(bc.indices) != 2
        throw("!BasicConstraint is only implemented for !equal with exactly 2 variables")
    end
    bc.fct = not_equal
    return bc
end

function not_equal(com::CS.CoM, constraint::BasicConstraint; logs = true)
    indices = constraint.indices

    changed = Dict{Int, Bool}()
    pruned  = zeros(Int, length(indices))
    pruned_below  = zeros(Int, length(indices))

    search_space = com.search_space
    # we always have only two variables
    v1 = search_space[indices[1]]
    v2 = search_space[indices[2]]
    fixed_v1 = isfixed(v1)
    fixed_v2 = isfixed(v2)
    if !fixed_v1 && !fixed_v2
        return ConstraintOutput(true, changed, pruned, pruned_below)
    elseif fixed_v1 && fixed_v2
        if value(v1) == value(v2)
            return ConstraintOutput(false, changed, pruned, pruned_below)
        end
        return ConstraintOutput(true, changed, pruned, pruned_below)
    end
    # one is fixed and one isn't
    if fixed_v1
        prune_v = v2
        prune_v_idx = 2
        other_val = value(v1)       
    else 
        prune_v = v1
        prune_v_idx = 1
        other_val = value(v2) 
    end
    if has(prune_v, other_val)
        if !rm!(com, prune_v, other_val)
            return ConstraintOutput(false, changed, pruned, pruned_below)
        end
        changed[indices[prune_v_idx]] = true
        pruned[prune_v_idx] = 1
    end
    return ConstraintOutput(true, changed, pruned, pruned_below)
end

"""
    not_equal(com::CoM, constraint::Constraint, value::Int, index::Int)

Returns whether the `not_equal` constraint can be still fulfilled.
"""
function not_equal(com::CoM, constraint::Constraint, value::Int, index::Int)
    if index == constraint.indices[1]
        other_var = com.search_space[constraint.indices[2]] 
    else
        other_var = com.search_space[constraint.indices[1]] 
    end
    return !issetto(other_var, value)
end
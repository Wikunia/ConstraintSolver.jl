"""
    equal(variables::Vector{Variable})

Create a BasicConstraint which will later be used by `equal(com, constraint)` \n
Can be used i.e by `add_constraint!(com, CS.equal([x,y,z])`.
"""
function equal(variables::Vector{Variable})
    internals = ConstraintInternals(
        0, # idx will be changed later
        var_vector_to_moi(variables),
        EqualSet(length(variables)),
        Int[v.idx for v in variables]
    )
    constraint = BasicConstraint(
      internals
    )
    constraint.std.hash = constraint_hash(constraint)
    return constraint
end

"""
    Base.:(==)(x::Variable, y::Variable)

Create a BasicConstraint which will later be used by `equal(com, constraint)` \n
Can be used i.e by `add_constraint!(com, x == y)`.
"""
function Base.:(==)(x::Variable, y::Variable)
    variables = [x, y]
    internals = ConstraintInternals(
        0, # idx will be changed later
        var_vector_to_moi(variables),
        EqualSet(2),
        Int[x.idx, y.idx]
    )
    bc = BasicConstraint(
       internals
    )
    bc.std.hash = constraint_hash(bc)
    return bc
end

function init_constraint!(
    com::CS.CoM,
    constraint::BasicConstraint,
    fct::MOI.VectorOfVariables,
    set::CS.EqualSet,
)
    indices = constraint.std.indices
    search_space = com.search_space
    intersect_vals = Set(intersect(CS.values.(search_space[indices])...))
    if isempty(intersect_vals)
        return false
    end
    for ind in indices
        for val in CS.values(search_space[ind])
            if !(val in intersect_vals)
                !rm!(com, search_space[ind], val) && return false
            end
        end
    end

    return true
end
"""
    prune_constraint!(com::CS.CoM, constraint::BasicConstraint, fct::MOI.VectorOfVariables, set::EqualSet; logs = true)

Reduce the number of possibilities given the equality constraint which sets all variables in `MOI.VectorOfVariables` to the same value.
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::BasicConstraint,
    fct::MOI.VectorOfVariables,
    set::EqualSet;
    logs = true,
)
    indices = constraint.std.indices

    search_space = com.search_space
    # is only needed if we want to set more
    if length(indices) > 2
        fixed_vals, unfixed_indices = fixed_vs_unfixed(search_space, indices)

        fixed_vals_set = Set(fixed_vals)
        # check if one value is used more than once
        if length(fixed_vals_set) > 1
            logs && @warn "The problem is infeasible"
            return false
        elseif length(fixed_vals_set) == 0
            for i=1:length(indices)
                v1 = search_space[indices[i]] 
                v1_changes = v1.changes[com.c_backtrack_idx]
                isempty(v1_changes) && continue
                for j=1:length(indices)
                    i == j && continue
                    v2 = search_space[indices[j]] 
                    for change in v1_changes
                        if change[1] == :remove_below
                            !remove_below!(com, v2, change[2]) && return false
                        elseif change[1] == :remove_above
                            !remove_above!(com, v2, change[2]) && return false
                        elseif change[1] == :rm && has(v2, change[2])
                            !rm!(com, v2, change[2]) && return false
                        end
                    end
                end
            end
            return true
        end

        # otherwise prune => set all variables to fixed value
        for i in unfixed_indices
            idx = indices[i]
            feasible = fix!(com, search_space[idx], fixed_vals[1])
            if !feasible
                return false
            end
        end
    else # faster for two variables
        v1 = search_space[indices[1]]
        v2 = search_space[indices[2]]
        fixed_v1 = isfixed(v1)
        fixed_v2 = isfixed(v2)
        if !fixed_v1 && !fixed_v2
            changes_v1 = v1.changes[com.c_backtrack_idx]
            changes_v2 = v2.changes[com.c_backtrack_idx]
            if isempty(changes_v1) && isempty(changes_v2)
                return true
            end
            for (changes, other_var) in zip((changes_v1, changes_v2), (v2, v1))
                for change in changes
                    if change[1] == :remove_below
                        !remove_below!(com, other_var, change[2]) && return false
                    elseif change[1] == :remove_above
                        !remove_above!(com, other_var, change[2]) && return false
                    elseif change[1] == :rm && has(other_var, change[2])
                        !rm!(com, other_var, change[2]) && return false
                    end
                end
            end
            return true
        elseif fixed_v1 && fixed_v2
            if CS.value(v1) != CS.value(v2)
                return false
            end
            return true
        end
        # one is fixed and one isn't
        if fixed_v1
            feasible = fix!(com, v2, CS.value(v1))
            if !feasible
                return false
            end
        else
            feasible = fix!(com, v1, CS.value(v2))
            if !feasible
                return false
            end
        end
    end
    return true
end

"""
    still_feasible(com::CoM, constraint::Constraint, fct::MOI.VectorOfVariables, set::EqualSet, value::Int, index::Int)

Return whether the constraint can be still fulfilled.
"""
function still_feasible(
    com::CoM,
    constraint::Constraint,
    fct::MOI.VectorOfVariables,
    set::EqualSet,
    value::Int,
    index::Int,
)
    variables = com.search_space
    for ind in constraint.std.indices
        ind == index && continue
        v = variables[ind]
        !has(v, value) && return false
    end
    return true
end

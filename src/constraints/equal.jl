"""
    equal(variables::Vector{Variable})

Create an EqualConstraint which will later be used by `equal(com, constraint)` \n
Can be used i.e by `add_constraint!(com, CS.equal([x,y,z])`.
"""
function equal(variables::Vector{Variable})
    internals = ConstraintInternals(
        0, # idx will be changed later
        var_vector_to_moi(variables),
        EqualSetInternal(length(variables)),
        Int[v.idx for v in variables]
    )
    constraint = EqualConstraint(
      internals,
      ones(Int, length(variables))
    )
    constraint.std.hash = constraint_hash(constraint)
    return constraint
end

"""
    Base.:(==)(x::Variable, y::Variable)

Create an EqualConstraint which will later be used by `equal(com, constraint)` \n
Can be used i.e by `add_constraint!(com, x == y)`.
"""
function Base.:(==)(x::Variable, y::Variable)
    variables = [x, y]
    internals = ConstraintInternals(
        0, # idx will be changed later
        var_vector_to_moi(variables),
        EqualSetInternal(2),
        Int[x.idx, y.idx]
    )
    bc = EqualConstraint(
       internals,
       ones(Int, 2)
    )
    bc.std.hash = constraint_hash(bc)
    return bc
end

function init_constraint!(
    com::CS.CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::CS.EqualSetInternal,
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

function apply_changes!(com::CS.CoM, v::Variable, changes::Vector{Tuple{Symbol, Int, Int, Int}}, first_ptr::Int)
    for i=first_ptr:length(changes)
        change = changes[i]
        if change[1] == :remove_below
            !remove_below!(com, v, change[2]) && return false
        elseif change[1] == :remove_above
            !remove_above!(com, v, change[2]) && return false
        elseif change[1] == :rm && has(v, change[2])
            !rm!(com, v, change[2]) && return false
        end
    end
end

"""
    prune_constraint!(com::CS.CoM, constraint::EqualConstraint, fct::MOI.VectorOfVariables, set::EqualSetInternal; logs = true)

Reduce the number of possibilities given the equality constraint which sets all variables in `MOI.VectorOfVariables` to the same value.
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::EqualSetInternal;
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
            # sync the changes in each variable
            for i=1:length(indices)
                v1 = search_space[indices[i]] 
                v1_changes = v1.changes[com.c_backtrack_idx]
                isempty(v1_changes) && continue
                for j=1:length(indices)
                    i == j && continue
                    v2 = search_space[indices[j]] 
                    apply_changes!(com, v2, v1_changes, constraint.first_ptrs[i])
                    constraint.first_ptrs[i] = length(v1_changes)+1
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
            apply_changes!(com, v2, changes_v1, constraint.first_ptrs[1])
            apply_changes!(com, v1, changes_v2, constraint.first_ptrs[2])
            constraint.first_ptrs[1] = length(changes_v1)+1
            constraint.first_ptrs[2] = length(changes_v2)+1
            return true
        elseif fixed_v1 && fixed_v2
            if CS.value(v1) != CS.value(v2)
                return false
            end
            return true
        end
        # one is fixed and one isn't
        if fixed_v1
            fix_v = 2
            feasible = fix!(com, v2, CS.value(v1))
            if !feasible
                return false
            end
        else
            feasible = fix!(com, v1, CS.value(v2))
            if !feasible
                return false
            end
            fix_v = 1
        end
    end
    return true
end

"""
    finished_pruning_constraint!(com::CS.CoM,
        constraint::EqualConstraint,
        fct::MOI.VectorOfVariables,
        set::EqualSetInternal)

Reset the first_ptrs to one for the next pruning step
"""
function finished_pruning_constraint!(com::CS.CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::EqualSetInternal)

    constraint.first_ptrs .= 1
end

"""
    still_feasible(com::CoM, constraint::EqualConstraint, fct::MOI.VectorOfVariables, set::EqualSetInternal, value::Int, index::Int)

Return whether the constraint can be still fulfilled.
"""
function still_feasible(
    com::CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::EqualSetInternal,
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

function is_solved_constraint(com::CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::EqualSetInternal,
) 
    values = CS.value.(com.search_space[constraint.std.indices])
    return all(v->v == values[1], values)
end
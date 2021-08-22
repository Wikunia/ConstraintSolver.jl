function init_constraint_struct(com, ::CPE.AllEqual, internals)
    EqualConstraint(internals, ones(Int, length(internals.indices)))
end

implements_activate(::Type{EqualConstraint}, ::Type{MOI.VectorOfVariables}, ::Type{CS.CPE.AllEqual}) = true

function activate_constraint!(
    com::CS.CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::CS.CPE.AllEqual
)
    indices = constraint.indices
    search_space = com.search_space
    intersect_vals = Set(intersect(CS.values.(search_space[indices])...))
    if isempty(intersect_vals)
        return false
    end
    for vidx in indices
        for val in CS.values(search_space[vidx])
            if !(val in intersect_vals)
                !rm!(com, search_space[vidx], val) && return false
            end
        end
    end

    return true
end

function apply_changes!(
    com::CS.CoM,
    v::Variable,
    changes,
    first_ptr::Int,
)
    for i in first_ptr:length(changes)
        change = changes[i]
        if change[1] == :remove_below
            !remove_below!(com, v, change[2]) && return false
        elseif change[1] == :remove_above
            !remove_above!(com, v, change[2]) && return false
        elseif change[1] == :rm && has(v, change[2])
            !rm!(com, v, change[2]) && return false
        end
    end
    return true
end

"""
    _prune_constraint!(com::CS.CoM, constraint::EqualConstraint, fct::MOI.VectorOfVariables, set::CPE.AllEqual; logs = false)

Reduce the number of possibilities given the equality constraint which sets all variables in `MOI.VectorOfVariables` to the same value.
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function _prune_constraint!(
    com::CS.CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::CPE.AllEqual;
    logs = false,
)
    indices = constraint.indices

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
            for i in 1:length(indices)
                v1 = search_space[indices[i]]
                v1_changes = view_changes(v1, com.c_step_nr)
                isnothing(v1_changes) && continue
                for j in 1:length(indices)
                    i == j && continue
                    v2 = search_space[indices[j]]
                    !apply_changes!(com, v2, v1_changes, constraint.first_ptrs[i]) &&
                        return false
                end
                constraint.first_ptrs[i] = length(v1_changes) + 1
            end
            return true
        end

        # otherwise prune => set all variables to fixed value
        for i in unfixed_indices
            vidx = indices[i]
            feasible = fix!(com, search_space[vidx], fixed_vals[1])
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
            num_changes_v1 = num_changes(v1, com.c_step_nr)
            num_changes_v2 = num_changes(v2, com.c_step_nr)
            if num_changes_v1 == 0 && num_changes_v2 == 0 
                return true
            end
            !apply_changes!(com, v2, view_changes(v1, com.c_step_nr), constraint.first_ptrs[1]) && return false
            !apply_changes!(com, v1, view_changes(v2, com.c_step_nr), constraint.first_ptrs[2]) && return false
            constraint.first_ptrs[1] = num_changes(v1, com.c_step_nr) + 1
            constraint.first_ptrs[2] = num_changes(v2, com.c_step_nr) + 1
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
        set::CPE.AllEqual)

Reset the first_ptrs to one for the next pruning step
"""
function finished_pruning_constraint!(
    com::CS.CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::CPE.AllEqual,
)

    constraint.first_ptrs .= 1
end

"""
    _still_feasible(com::CoM, constraint::EqualConstraint, fct::MOI.VectorOfVariables, set::CPE.AllEqual, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled.
"""
function _still_feasible(
    com::CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::CPE.AllEqual,
    vidx::Int,
    value::Int,
)
    variables = com.search_space
    for cvidx in constraint.indices
        if cvidx == vidx
            continue
        end
        v = variables[cvidx]
        !has(v, value) && return false
    end
    return true
end

function _is_constraint_solved(
    com,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::CPE.AllEqual,
    values::Vector{Int},
)
    return all(v -> v == values[1], values)
end

"""
    _is_constraint_violated(
        com::CoM,
        constraint::EqualConstraint,
        fct::MOI.VectorOfVariables,
        set::CPE.AllEqual
    )

Checks if the constraint is violated as it is currently set. This can happen inside an
inactive reified or indicator constraint.
"""
function _is_constraint_violated(
    com::CoM,
    constraint::EqualConstraint,
    fct::MOI.VectorOfVariables,
    set::CPE.AllEqual,
)
    found_first_val = false
    first_val = 0
    for var in com.search_space[constraint.indices]
        if isfixed(var)
            found_first_val = true
            first_val = CS.value(var)
            break
        end
    end
    !found_first_val && return false
    return !all(
        CS.value(var) == first_val
        for var in com.search_space[constraint.indices] if isfixed(var)
    )
end

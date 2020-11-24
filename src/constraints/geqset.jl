function init_constraint_struct(::Type{GeqSetInternal}, internals)
    GeqSetConstraint(
        internals,
        internals.indices[1],
        internals.indices[2:end],
        []
    )
end

"""
    init_constraint!(com::CS.CoM, constraint::AllDifferentConstraint, fct::MOI.VectorOfVariables, set::AllDifferentSetInternal;
                     active = true)

Initialize the AllDifferentConstraint by filling matching_init
"""
function init_constraint!(
    com::CS.CoM,
    constraint::GeqSetConstraint,
    fct::MOI.VectorOfVariables,
    set::GeqSetInternal;
    active = true
)
    for other_constraint in com.constraints
        if other_constraint.indices ⊆ constraint.indices[2:end]
            push!(constraint.sub_constraint_idxs, other_constraint.idx)
        end
    end
    return true
end

function update_init_constraint!(
    com::CS.CoM,
    constraint::GeqSetConstraint,
    fct::MOI.VectorOfVariables,
    set::GeqSetInternal,
    constraints::Vector{<:Constraint}
)
    for other_constraint in constraints
        if other_constraint.indices ⊆ constraint.indices[2:end]
            push!(constraint.sub_constraint_idxs, other_constraint.idx)
        end
    end
    return true
end

function prune_constraint!(
    com::CS.CoM,
    constraint::GeqSetConstraint,
    fct::MOI.VectorOfVariables,
    set::GeqSetInternal;
    logs = true,
)
    # find the maximum of the minima
    max_val = -typemax(Int)
    variables = com.search_space
    for vidx in constraint.greater_than
        max_val = max(variables[vidx].min, max_val)
    end
    feasible = remove_below!(com, variables[constraint.vidx], max_val)
    !feasible && return false

    # remove values bigger than the maximum of constraint.vidx
    # as this violates constraint.vidx >= constraint.greater_than
    max_val_variable = variables[constraint.vidx].max
    for vidx in constraint.greater_than
        feasible = remove_above!(com, variables[vidx], max_val_variable)
        !feasible && return false
    end

    # remove more values from constraint.vidx by checking the maximal
    # minimum value in all different constraints that are completely inside
    max_min = -typemax(Int)
    for cidx in constraint.sub_constraint_idxs
        sub_constraint = com.constraints[cidx]
        !(sub_constraint isa AllDifferentConstraint) && continue
        min_vals, max_vals = get_sorted_extrema(com, sub_constraint, 0, 0, 0)
        cmax_min = min_vals[1]
        for i in 2:length(sub_constraint.indices)
            if min_vals[i] <= cmax_min
                cmax_min += 1
            else
                cmax_min = min_vals[i]
            end
        end
        max_min = max(max_min, cmax_min)
    end
    feasible = remove_below!(com, variables[constraint.vidx], max_min)
    return feasible
end

function still_feasible(
    com::CoM,
    constraint::GeqSetConstraint,
    fct::MOI.VectorOfVariables,
    set::GeqSetInternal,
    vidx::Int,
    value::Int,
)
    if vidx == constraint.vidx
        return true
    end
    variables = com.search_space
    return value <= variables[constraint.vidx].max
end

function is_solved_constraint(
    constraint::GeqSetConstraint,
    fct::MOI.VectorOfVariables,
    set::GeqSetInternal,
    values::Vector{Int}
)
    max_val = values[1]
    for i in 2:length(values)
        values[i] > max_val && return false
    end
    return true
end

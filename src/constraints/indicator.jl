"""
    prune_constraint!(
        com::CS.CoM,
        constraint::IndicatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS;
        logs = true,
    ) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}

Prune the search space given the indicator constraint. An indicator constraint is of the form `b => {x + y == 2}`.
Where the constraint in `{ }` is currently a linear constraint.

Return whether the search space is still feasible.
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS;
    logs = true,
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    indicator_var_idx = constraint.std.indices[1]
    search_space = com.search_space
    indicator_var = search_space[indicator_var_idx]
    # still feasible but nothing to prune
    !isfixed(indicator_var) && return true
    # if active
    CS.value(indicator_var) != Int(constraint.activate_on) && return true
    inner_constraint = constraint.inner_constraint
    return prune_constraint!(com, inner_constraint, inner_constraint.std.fct, inner_constraint.std.set; logs=logs)
end

"""
    still_feasible(
        com::CoM,
        constraint::IndicatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS,
        val::Int,
        index::Int,
    ) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}

Return whether the search space is still feasible when setting `search_space[index]` to value.
"""
function still_feasible(
    com::CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS,
    val::Int,
    index::Int,
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    indicator_var_idx = constraint.std.indices[1]
    search_space = com.search_space
    indicator_var = search_space[indicator_var_idx]
    # still feasible but nothing to prune
    !isfixed(indicator_var) && index != indicator_var_idx && return true
    # if deactivating or is deactivated
    if index != indicator_var_idx
        CS.value(indicator_var) != Int(constraint.activate_on) && return true
    else
        val != Int(constraint.activate_on) && return true
    end
    # if activating or activated check the inner constraint
    inner_constraint = constraint.inner_constraint
    return still_feasible(com, inner_constraint, inner_constraint.std.fct, inner_constraint.std.set, val, index)
end

"""
    is_solved_constraint(
        constraint::IndicatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS,
        values::Vector{Int}
    ) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}

Return whether given `values` the constraint is fulfilled.
"""
function is_solved_constraint(
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS,
    values::Vector{Int}
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    if values[1] == Int(constraint.activate_on)
        inner_constraint = constraint.inner_constraint
        return is_solved_constraint(inner_constraint, inner_constraint.std.fct, inner_constraint.std.set, values[2:end])
    end
    return true
end
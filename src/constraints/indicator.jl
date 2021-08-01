"""
    init_constraint!(
        com::CS.CoM,
        constraint::IndicatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS
    ) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}

Initialize the inner constraint if it needs to be initialized
"""
function init_constraint!(
    com::CS.CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::IS;
    active = true
) where {
    A,
    T<:Real,
    ASS<:MOI.AbstractScalarSet,
    IS<:Union{IndicatorSet{A},MOI.IndicatorSet{A,ASS}},
}
    indicator_vidx = constraint.indices[1]
    search_space = com.search_space
    indicator_var = search_space[indicator_vidx]
    inner_constraint = constraint.inner_constraint

    # check which methods that inner constraint supports
    set_impl_functions!(com, inner_constraint)

    if inner_constraint.impl.init
        feasible = init_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set
        )
        # map the bounds to the indicator constraint
        constraint.bound_rhs = inner_constraint.bound_rhs
        # the indicator can't be activated if inner constraint is infeasible
        if !feasible && active
            !rm!(com, indicator_var, Int(constraint.activate_on)) && return false
        end
    end
    # still feasible
    return true
end

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
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::IS;
    logs = true,
) where {
    A,
    T<:Real,
    ASS<:MOI.AbstractScalarSet,
    IS<:Union{IndicatorSet{A},MOI.IndicatorSet{A,ASS}},
}
    indicator_vidx = constraint.indices[1]
    search_space = com.search_space
    indicator_var = search_space[indicator_vidx]
    # still feasible but nothing to prune
    !isfixed(indicator_var) && return true

    inner_constraint = constraint.inner_constraint
    # check if active
    CS.value(indicator_var) != Int(constraint.activate_on) && return true
    !activate_inner!(com, constraint) && return false
    return prune_constraint!(
        com,
        inner_constraint,
        inner_constraint.fct,
        inner_constraint.set;
        logs = logs,
    )
end

"""
    still_feasible(
        com::CoM,
        constraint::IndicatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS,
        vidx::Int,
        val::Int,
    ) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}

Return whether the search space is still feasible when setting `search_space[vidx]` to value.
"""
function still_feasible(
    com::CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::IS,
    vidx::Int,
    val::Int,
) where {
    A,
    T<:Real,
    ASS<:MOI.AbstractScalarSet,
    IS<:Union{IndicatorSet{A},MOI.IndicatorSet{A,ASS}},
}
    indicator_vidx = constraint.indices[1]
    search_space = com.search_space
    indicator_var = search_space[indicator_vidx]
    # still feasible but nothing to prune
    !isfixed(indicator_var) && vidx != indicator_vidx && return true
    # if deactivating or is deactivated
    if vidx != indicator_vidx
        CS.value(indicator_var) != Int(constraint.activate_on) && return true
    else
        val != Int(constraint.activate_on) && return true
    end

    # if activating or activated check the inner constraint
    inner_constraint = constraint.inner_constraint
    # check if already violated
    violated = is_constraint_violated(
        com,
        inner_constraint,
        inner_constraint.fct,
        inner_constraint.set,
    )
    violated && return false
    # otherwise check if feasible when setting vidx to val
    return still_feasible(
        com,
        inner_constraint,
        inner_constraint.fct,
        inner_constraint.set,
        vidx,
        val,
    )
end

"""
    is_constraint_solved(
        constraint::IndicatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS,
        values::Vector{Int}
    ) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}

Return whether given `values` the constraint is fulfilled.
"""
function is_constraint_solved(
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::IS,
    values::Vector{Int},
) where {
    A,
    T<:Real,
    ASS<:MOI.AbstractScalarSet,
    IS<:Union{IndicatorSet{A},MOI.IndicatorSet{A,ASS}},
}
    if values[1] == Int(constraint.activate_on)
        inner_constraint = constraint.inner_constraint
        return is_constraint_solved(
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
            values[2:end],
        )
    end
    return true
end

"""
    is_constraint_violated(
        com::CoM,
        constraint::IndicatorConstraint,
        fct::Union{MOI.VectorOfVariables,VAF{T}},
        set::IS
    ) where {
        A,
        T<:Real,
        ASS<:MOI.AbstractScalarSet,
        IS<:Union{IndicatorSet{A},MOI.IndicatorSet{A,ASS}},
    }

Checks if the constraint is violated as it is currently set. This can happen inside an
inactive reified or indicator constraint.
"""
function is_constraint_violated(
    com::CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set::IS,
) where {
    A,
    T<:Real,
    ASS<:MOI.AbstractScalarSet,
    IS<:Union{IndicatorSet{A},MOI.IndicatorSet{A,ASS}},
}
    if all(isfixed(var) for var in com.search_space[constraint.indices])
        return !is_constraint_solved(
            constraint,
            fct,
            set,
            [CS.value(var) for var in com.search_space[constraint.indices]],
        )
    end

    indicator_vidx = constraint.indices[1]
    indicator_var = com.search_space[indicator_vidx]
    if isfixed(indicator_var) && CS.value(indicator_var) == Int(constraint.activate_on)
        inner_constraint = constraint.inner_constraint
        return is_constraint_violated(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
        )
    end
    return false
end

function changed_var!(
    com::CS.CoM,
    constraint::IndicatorConstraint,
    fct,
    set,
    vidx::Int
) where {T<:Real}
    inner_constraint = constraint.inner_constraint
    changed_var!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, vidx)
end
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
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    inner_constraint = constraint.inner_constraint

    # check which methods that inner constraint supports
    set_impl_functions!(com, inner_constraint)

    if inner_constraint.impl.init
        feasible = init_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set; active=false)
        # map the bounds to the indicator constraint
        constraint.bound_rhs = inner_constraint.bound_rhs
        return feasible
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
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS;
    logs = true,
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    indicator_var_idx = constraint.indices[1]
    search_space = com.search_space
    indicator_var = search_space[indicator_var_idx]
    # still feasible but nothing to prune
    !isfixed(indicator_var) && return true
    # if active
    CS.value(indicator_var) != Int(constraint.activate_on) && return true
    inner_constraint = constraint.inner_constraint
    return prune_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set; logs=logs)
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
    indicator_var_idx = constraint.indices[1]
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
    return still_feasible(com, inner_constraint, inner_constraint.fct, inner_constraint.set, val, index)
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
        return is_solved_constraint(inner_constraint, inner_constraint.fct, inner_constraint.set, values[2:end])
    end
    return true
end


"""
    update_best_bound_constraint!(com::CS.CoM,
        constraint::IndicatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS,
        var_idx::Int,
        lb::Int,
        ub::Int
    ) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}

Update the bound constraint associated with this constraint. This means that the `bound_rhs` bounds will be changed according to 
the possible values the table constraint allows. `var_idx`, `lb` and `ub` don't are not considered atm.
Additionally only a rough estimated bound is used which can be computed relatively fast. 
This method calls the inner_constraint method if it exists and the indicator is activated.
"""
function update_best_bound_constraint!(com::CS.CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS,
    var_idx::Int,
    lb::Int,
    ub::Int
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    inner_constraint = constraint.inner_constraint
    indicator_var_idx = constraint.indices[1]
    search_space = com.search_space
    indicator_var = search_space[indicator_var_idx]
    if inner_constraint.impl.update_best_bound
        if CS.issetto(indicator_var, Int(constraint.activate_on)) 
            return update_best_bound_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, var_idx, lb, ub)
        else
            # if not activated (for example in a different subtree) we reset the bounds
            for rhs in constraint.bound_rhs
                rhs.lb = typemin(Int64)
                rhs.ub = typemax(Int64)
            end
        end
    end
    return true
end

function single_reverse_pruning_constraint!(
    com::CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS,
    var::Variable,
    backtrack_idx::Int
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    inner_constraint = constraint.inner_constraint
    # the variable must be part of the inner constraint
    if inner_constraint.impl.single_reverse_pruning && (var.idx != constraint.indices[1] || constraint.indicator_in_inner)
        single_reverse_pruning_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, var, backtrack_idx)
    end
end

function reverse_pruning_constraint!(
    com::CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS,
    backtrack_id::Int
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.reverse_pruning
        reverse_pruning_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, backtrack_id)
    end
end
  
function restore_pruning_constraint!(
    com::CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS,
    prune_steps::Union{Int, Vector{Int}}
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.restore_pruning
        restore_pruning_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set, prune_steps)
    end
end

function finished_pruning_constraint!(com::CS.CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables, VAF{T}},
    set::IS
) where {A, T<:Real, ASS<:MOI.AbstractScalarSet, IS<:Union{IndicatorSet{A}, MOI.IndicatorSet{A, ASS}}}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.finished_pruning
        finished_pruning_constraint!(com, inner_constraint, inner_constraint.fct, inner_constraint.set)
    end
end
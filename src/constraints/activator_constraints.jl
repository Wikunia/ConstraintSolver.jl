"""
    update_best_bound_constraint!(com::CS.CoM,
        constraint::ActivatorConstraint,
        fct::Union{MOI.VectorOfVariables, VAF{T}},
        set::IS,
        vidx::Int,
        lb::Int,
        ub::Int
    ) where {T<:Real}

Update the bound constraint associated with this constraint. This means that the `bound_rhs` bounds will be changed according to
the possible values the table constraint allows. `vidx`, `lb` and `ub` don't are not considered atm.
Additionally only a rough estimated bound is used which can be computed relatively fast.
This method calls the inner_constraint method if it exists and the indicator is activated.
"""
function update_best_bound_constraint!(
    com::CS.CoM,
    constraint::IndicatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
    vidx::Int,
    lb::Int,
    ub::Int,
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    activator_vidx = constraint.indices[1]
    search_space = com.search_space
    activator_var = search_space[activator_vidx]
    if inner_constraint.impl.update_best_bound
        if CS.issetto(activator_var, Int(constraint.activate_on))
            return update_best_bound_constraint!(
                com,
                inner_constraint,
                inner_constraint.fct,
                inner_constraint.set,
                vidx,
                lb,
                ub,
            )
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
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
    var::Variable,
    backtrack_idx::Int,
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    # the variable must be part of the inner constraint
    if inner_constraint.impl.single_reverse_pruning &&
       (var.idx != constraint.indices[1] || constraint.activator_in_inner)
        single_reverse_pruning_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
            var,
            backtrack_idx,
        )
    end
end

function reverse_pruning_constraint!(
    com::CoM,
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
    backtrack_id::Int,
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.reverse_pruning
        reverse_pruning_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
            backtrack_id,
        )
    end
end

function restore_pruning_constraint!(
    com::CoM,
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
    prune_steps::Union{Int,Vector{Int}},
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.restore_pruning
        restore_pruning_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
            prune_steps,
        )
    end
end

function finished_pruning_constraint!(
    com::CS.CoM,
    constraint::ActivatorConstraint,
    fct::Union{MOI.VectorOfVariables,VAF{T}},
    set,
) where {
    T<:Real,
}
    inner_constraint = constraint.inner_constraint
    if inner_constraint.impl.finished_pruning
        finished_pruning_constraint!(
            com,
            inner_constraint,
            inner_constraint.fct,
            inner_constraint.set,
        )
    end
end

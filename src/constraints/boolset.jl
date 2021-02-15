function init_constraint_struct(set::BoolSet{F1,F2}, internals) where {F1,F2}
    f = MOIU.eachscalar(internals.fct)

    lhs_fct = f[1:set.lhs_dimension]
    rhs_fct = f[end-set.rhs_dimension+1:end]

    if F1 <: MOI.ScalarAffineFunction
        lhs_fct = get_saf(lhs_fct)
    end
    if F2 <: MOI.ScalarAffineFunction
        rhs_fct = get_saf(rhs_fct)
    end

    if F1 <: MOI.VectorOfVariables
        lhs_fct = get_vov(lhs_fct)
    end
    if F2 <: MOI.VectorOfVariables
        rhs_fct = get_vov(rhs_fct)
    end

   
    lhs = get_constraint(lhs_fct, set.lhs_set)
    rhs = get_constraint(rhs_fct, set.rhs_set)

    return bool_constraint(set, internals, lhs, rhs)
end

function bool_constraint(::AndSet, internals, lhs, rhs)
    AndConstraint(
        internals,
        lhs,
        rhs
    )
end

function bool_constraint(::OrSet, internals, lhs, rhs)
    OrConstraint(
        internals,
        lhs,
        rhs
    )
end

function single_reverse_pruning_constraint!(
    com::CoM,
    constraint::BoolConstraint,
    fct::VAF{T},
    set::BoolSet,
    var::Variable,
    backtrack_idx::Int,
) where {
    T<:Real,
}
    for inner_constraint in (constraint.lhs, constraint.rhs)
        # the variable must be part of the inner constraint
        # Todo: Speed up the `in` here
        if inner_constraint.impl.single_reverse_pruning && var.idx in inner_constraint.indices
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
end

function reverse_pruning_constraint!(
    com::CoM,
    constraint::BoolConstraint,
    fct::VAF{T},
    set::BoolSet,
    backtrack_id::Int,
) where {
    T<:Real,
}
    for inner_constraint in (constraint.lhs, constraint.rhs)
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
end

function restore_pruning_constraint!(
    com::CoM,
    constraint::BoolConstraint,
    fct::VAF{T},
    set::BoolSet,
    prune_steps::Union{Int,Vector{Int}},
) where {
    T<:Real,
}
    for inner_constraint in (constraint.lhs, constraint.rhs)
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
end

function finished_pruning_constraint!(
    com::CS.CoM,
    constraint::BoolConstraint,
    fct::VAF{T},
    set::BoolSet,
) where {
    T<:Real,
}
    for inner_constraint in (constraint.lhs, constraint.rhs)
        if inner_constraint.impl.finished_pruning
            finished_pruning_constraint!(
                com,
                inner_constraint,
                inner_constraint.fct,
                inner_constraint.set,
            )
        end
    end
end

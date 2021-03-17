function init_constraint_struct(set::AbstractBoolSet{F1,F2}, internals) where {F1,F2}
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

anti_set(::Type{<:AndSet}) = OrSet
anti_set(::Type{<:OrSet}) = AndSet
apply_bool_operator(::Type{<:AndSet}, lhs, rhs) = lhs && rhs
apply_bool_operator(::Type{<:OrSet}, lhs, rhs)  = lhs || rhs

function apply_bool_operator(::Type{<:AndSet}, lhs_fct, rhs_fct, args...) 
    lhs_fct(args...) && rhs_fct(args...)
end

function apply_bool_operator(::Type{<:OrSet}, lhs_fct, rhs_fct, args...)  
    lhs_fct(args...) || rhs_fct(args...)
end

function apply_anti_bool_operator(s::Type{<:AbstractBoolSet}, args...)
    apply_bool_operator(anti_set(s), args...)
end

function init_constraint!(
    com::CS.CoM,
    constraint::BoolConstraint,
    fct,
    set::AbstractBoolSet;
)
    set_impl_functions!(com,  constraint.lhs)
    set_impl_functions!(com,  constraint.rhs)
    lhs_feasible = true
    if constraint.lhs.impl.init   
        lhs_feasible = init_constraint!(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
    end
    rhs_feasible = true
    if constraint.rhs.impl.init   
        rhs_feasible = init_constraint!(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
    end
    return apply_bool_operator(typeof(set), lhs_feasible, rhs_feasible)
end

"""
    is_constraint_solved(
        constraint::BoolConstraint,
        fct,
        set::AbstractBoolSet,
        values::Vector{Int},
    )  

Check if the constraint is solved gived the `values`
"""
function is_constraint_solved(
    constraint::BoolConstraint,
    fct,
    set::AbstractBoolSet,
    values::Vector{Int},
)
    apply_bool_operator(typeof(set), lhs_solved, rhs_solved, constraint, values)
end

function lhs_solved(constraint::BoolConstraint, values::Vector{Int})
    lhs_num_vars = get_num_vars(constraint.lhs.fct)
    return is_constraint_solved(constraint.lhs, constraint.lhs.fct, constraint.lhs.set, values[1:lhs_num_vars])
end

function rhs_solved(constraint::BoolConstraint, values::Vector{Int})
    rhs_num_vars = get_num_vars(constraint.rhs.fct)
    return is_constraint_solved(constraint.rhs, constraint.rhs.fct, constraint.rhs.set, values[end-rhs_num_vars+1:end])
end

function is_lhs_constraint_violated(com, constraint)
    is_constraint_violated(com, constraint.lhs, constraint.lhs.fct, constraint.lhs.set)
end

function is_rhs_constraint_violated(com, constraint)
    is_constraint_violated(com, constraint.rhs, constraint.rhs.fct, constraint.rhs.set)
end

"""
    function is_constraint_violated(
        com::CoM,
        constraint::BoolConstraint,
        fct,
        set::AbstractBoolSet,
    )

Check if the inner constraints are violated and apply the boolean operator to the inverse 
"""
function is_constraint_violated(
    com::CoM,
    constraint::BoolConstraint,
    fct,
    set::AbstractBoolSet,
)
    return apply_anti_bool_operator(
        typeof(set),
        is_lhs_constraint_violated,
        is_rhs_constraint_violated,
        com,
        constraint
    )
end

"""
    activate_lhs!(com, constraint::BoolConstraint)

Activate the lhs constraint of `constraint` when not activated yet.
Saves at which stage it was activated.
"""
function activate_lhs!(com, constraint::BoolConstraint)
    lhs = constraint.lhs
    if !constraint.lhs_activated && lhs.impl.activate 
        !activate_constraint!(com, lhs, lhs.fct, lhs.set) && return false
        constraint.lhs_activated = true
        constraint.lhs_activated_in_backtrack_idx = com.c_backtrack_idx
    end
    return true
end

"""
    activate_rhs!(com, constraint::BoolConstraint)

Activate the rhs constraint of `constraint` when not activated yet.
Saves at which stage it was activated.
"""
function activate_rhs!(com, constraint::BoolConstraint)
    rhs = constraint.rhs
    if !constraint.rhs_activated && rhs.impl.activate 
        !activate_constraint!(com, rhs, rhs.fct, rhs.set) && return false
        constraint.rhs_activated = true
        constraint.rhs_activated_in_backtrack_idx = com.c_backtrack_idx
    end
    return true
end

function single_reverse_pruning_constraint!(
    com::CoM,
    constraint::BoolConstraint,
    fct::VAF{T},
    set::AbstractBoolSet,
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
    set::AbstractBoolSet,
    backtrack_id::Int,
) where {
    T<:Real,
}
    # check if inner constraint should be deactived again
    if constraint.lhs_activated && backtrack_id == constraint.lhs_activated_in_backtrack_idx
        constraint.lhs_activated = false
        constraint.lhs_activated_in_backtrack_idx = 0
    end
    if constraint.rhs_activated && backtrack_id == constraint.rhs_activated_in_backtrack_idx
        constraint.rhs_activated = false
        constraint.rhs_activated_in_backtrack_idx = 0
    end

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
    set::AbstractBoolSet,
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
    set::AbstractBoolSet,
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

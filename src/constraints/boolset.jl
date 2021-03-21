function init_constraint_struct(com, set::AbstractBoolSet{F1,F2}, internals) where {F1,F2}
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

   
    lhs = get_constraint(com, lhs_fct, set.lhs_set)
    rhs = get_constraint(com, rhs_fct, set.rhs_set)

    return bool_constraint(set, com, internals, lhs, rhs)
end

function bool_constraint(::XorSet, com, internals, lhs, rhs)
    XorConstraint(
        internals,
        BoolConstraintInternals(lhs, rhs),
        get_anti_constraint(com, lhs),
        get_anti_constraint(com, rhs)
    )
end

function bool_constraint(::NXorSet, com, internals, lhs, rhs)
    NXorConstraint(
        internals,
        BoolConstraintInternals(lhs, rhs),
        get_anti_constraint(com, lhs),
        get_anti_constraint(com, rhs)
    )
end

for (set, bool_data) in BOOL_SET_TO_CONSTRAINT
    get(bool_data, :specific_constraint, false) && continue
    @eval begin
        function bool_constraint(::$set, com, internals, lhs, rhs)
            $(bool_data.constraint)(
                com,
                internals,
                lhs,
                rhs
            )
        end
    end
end

"""
    anti_set(::Type{<:AbstractBoolSet}) 

Return the type of the anti bool set so AndSet => OrSet
"""
anti_set(::Type{<:AndSet}) = OrSet
anti_set(::Type{<:OrSet}) = AndSet
anti_set(::Type{<:XorSet}) = NXorSet
anti_set(::Type{<:NXorSet}) = XorSet

"""
    anti_constraint_type(::Type{<:AbstractBoolSet}) 

Return the constraint of the anti bool set so AndSet => OrConstraint
"""
anti_constraint_type(::Type{<:AndSet}) = OrConstraint
anti_constraint_type(::Type{<:OrSet}) = AndConstraint
anti_constraint_type(::Type{<:XorSet}) = NXorConstraint
anti_constraint_type(::Type{<:NXorSet}) = XorConstraint

for (set, bool_data) in BOOL_SET_TO_CONSTRAINT
    res_op = get(bool_data, :res_op, :identity)
    if get(bool_data, :needs_call, false)
        @eval begin
            apply_bool_operator(::Type{<:$(set)}, lhs, rhs) = $(Expr(:call, res_op, Expr(:call, bool_data.op, :lhs, :rhs)))

            function apply_bool_operator(::Type{<:$set}, lhs_fct, rhs_fct, args...) 
                $(Expr(:call, res_op, Expr(:call, bool_data.op, :(lhs_fct(args...)), :(rhs_fct(args...)))))
            end
        end
    else
        @eval begin
            apply_bool_operator(::Type{<:$(set)}, lhs, rhs) = $(Expr(:call, res_op, Expr(bool_data.op, :lhs, :rhs)))

            function apply_bool_operator(::Type{<:$set}, lhs_fct, rhs_fct, args...) 
                $(Expr(:call, res_op, Expr(bool_data.op, :(lhs_fct(args...)), :(rhs_fct(args...)))))
            end
        end
    end
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
   init_lhs_and_rhs!(com, constraint, fct, set)
end

function init_lhs_and_rhs!(
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
    # check only for && constraint if both are feasible
    if set isa AndSet
        return lhs_feasible && rhs_feasible
    end
    return true
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

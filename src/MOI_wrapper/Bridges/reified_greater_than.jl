struct ReifiedGreaterToLessThanBridge{T,A} <: MOIBC.AbstractBridge
    constraint::CI{MOI.VectorAffineFunction{T}, ReifiedSet{A,MOI.LessThan{T}}}
end

function MOIBC.bridge_constraint(
    bridge::Type{<:ReifiedGreaterToLessThanBridge{T}},
    model::MOI.ModelLike,
    f::MOI.VectorAffineFunction,
    s::ReifiedSet{A, MOI.GreaterThan{T}}
) where {T,A}
    flipped_f = MOIU.operate(-, T, f)
    flipped_inner_s = MOIBC.map_set(MOIBC.GreaterToLessBridge{T}, s.set)
    # flipped_inner_f = MOIU.operate(-, T, s.func)
    flipped_s = ReifiedSet{A,MOI.LessThan{T}}(s.func, flipped_inner_s, 2)
    ci = MOI.add_constraint(model,
        flipped_f,flipped_s
    )
    return ReifiedGreaterToLessThanBridge{T,A}(ci)
end

function MOIB.added_constrained_variable_types(
    ::Type{<:ReifiedGreaterToLessThanBridge},
)
    return []
end
function MOIB.added_constraint_types(
    ::Type{ReifiedGreaterToLessThanBridge{T,A}},
) where {T,A}
    return [
        (MOI.VectorAffineFunction{T}, ReifiedSet{A,MOI.LessThan{T}})
    ]
end

function MOI.Bridges.Constraint.concrete_bridge_type(
    ::Type{<:ReifiedGreaterToLessThanBridge{T}},
    G::Type{<:MOI.VectorAffineFunction},
    ::Type{RS},
) where {T,A,IT<:MOI.GreaterThan{T}, RS<:ReifiedSet{A,IT}}
    F = MOIU.promote_operation(-, T, MOI.ScalarAffineFunction{T})
    return ReifiedGreaterToLessThanBridge{T,A}
end

function MOI.supports_constraint(::Type{<:ReifiedGreaterToLessThanBridge{T}},
    ::Type{<:MOI.VectorAffineFunction}, ::Type{RS}) where {T, A,RS<:ReifiedSet{A, MOI.GreaterThan{T}}}
    return true
end

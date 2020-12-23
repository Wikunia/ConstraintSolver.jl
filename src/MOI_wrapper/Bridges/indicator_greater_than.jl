struct IndicatorGreaterToLessThanBridge{T,A} <: MOIBC.AbstractBridge
    constraint::CI{MOI.VectorAffineFunction{T}, MOI.IndicatorSet{A,MOI.LessThan{T}}}
end

function MOIBC.bridge_constraint(
    bridge::Type{<:IndicatorGreaterToLessThanBridge{T}},
    model::MOI.ModelLike,
    f::MOI.VectorAffineFunction,
    s::MOI.IndicatorSet{A, MOI.GreaterThan{T}}
) where {T,A}
    flipped_f = MOIU.operate(-, T, f)
    flipped_inner_s = MOIBC.map_set(MOIBC.GreaterToLessBridge{T}, s.set)
    flipped_s = MOI.IndicatorSet{A}(flipped_inner_s)
    ci = MOI.add_constraint(model,
        flipped_f,flipped_s
    )
    return IndicatorGreaterToLessThanBridge{T,A}(ci)
end

function MOIB.added_constrained_variable_types(
    ::Type{<:IndicatorGreaterToLessThanBridge},
)
    return []
end
function MOIB.added_constraint_types(
    ::Type{IndicatorGreaterToLessThanBridge{T,A}},
) where {T,A}
    return [
        (MOI.VectorAffineFunction{T}, MOI.IndicatorSet{A,MOI.LessThan{T}})
    ]
end

function MOI.Bridges.Constraint.concrete_bridge_type(
    ::Type{<:IndicatorGreaterToLessThanBridge{T}},
    G::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IT<:MOI.GreaterThan{T}, IS<:MOI.IndicatorSet{A,IT}}
    F = MOIU.promote_operation(-, T, MOI.ScalarAffineFunction{T})
    return IndicatorGreaterToLessThanBridge{T,A}
end

function MOI.supports_constraint(::Type{<:IndicatorGreaterToLessThanBridge{T}},
    ::Type{<:MOI.VectorAffineFunction}, ::Type{IS}) where {T, A,IS<:MOI.IndicatorSet{A, MOI.GreaterThan{T}}}
    return true
end

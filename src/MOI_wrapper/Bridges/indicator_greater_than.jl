struct IndicatorGreaterToLessBridge{
    T,
    F<:MOI.VectorAffineFunction,
    G<:MOI.VectorAffineFunction,
    A
} <: MOIBC.FlipSignBridge{T,MOI.IndicatorSet{A},MOI.IndicatorSet{A},F,G}
    constraint::CI{F,MOI.IndicatorSet{A,MOI.LessThan{T}}}
end

function MOIBC.map_function(::Type{<:IndicatorGreaterToLessBridge{T}}, func) where {T}
    # apply the operator only for the inner constraint part (here the second part)
    operate_vector_affine_function_part(-, T, func, 2)
end

function MOIBC.map_set(::Type{<:IndicatorGreaterToLessBridge}, set::MOI.IndicatorSet{A,<:MOI.GreaterThan}) where A
    inner_set = set.set
    return MOI.IndicatorSet{A}(MOI.LessThan(-inner_set.lower))
end
function MOIBC.inverse_map_set(::Type{<:IndicatorGreaterToLessBridge}, set::MOI.IndicatorSet{A,<:MOI.LessThan}) where A
    inner_set = set.set
    return MOI.IndicatorSet{A}(MOI.GreaterThan(-inner_set.upper))
end

function MOIB.added_constrained_variable_types(::Type{<:IndicatorGreaterToLessBridge})
    return []
end
function MOIB.added_constraint_types(
    ::Type{<:IndicatorGreaterToLessBridge{T,F,G,A}},
) where {T,F,G,A}
    return [(F, MOI.IndicatorSet{A,MOI.LessThan{T}})]
end

function MOIBC.concrete_bridge_type(
    ::Type{<:IndicatorGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:MOI.IndicatorSet{A,MOI.GreaterThan{T}}}
    return IndicatorGreaterToLessBridge{T,MOI.VectorAffineFunction{T},MOI.VectorAffineFunction{T},A}
end

function MOI.supports_constraint(
    ::Type{<:IndicatorGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:MOI.IndicatorSet{A,MOI.GreaterThan{T}}}
    return true
end

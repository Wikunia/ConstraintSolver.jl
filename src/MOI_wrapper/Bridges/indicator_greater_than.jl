const UnionGT{T} = Union{Strictly{T, MOI.GreaterThan{T}}, MOI.GreaterThan{T}}

abstract type
    IndicatorGreaterToLessBridge{
        T,F,G,A
    } <: MOIBC.FlipSignBridge{T,MOI.IndicatorSet{A},MOI.IndicatorSet{A},F,G}
end

struct IndicatorGreaterToLessUnstrictBridge{
    T,
    F<:MOI.VectorAffineFunction,
    G<:MOI.VectorAffineFunction,
    A
} <: IndicatorGreaterToLessBridge{T,F,G,A}
    constraint::CI{F,MOI.IndicatorSet{A,MOI.LessThan{T}}}
end

struct IndicatorGreaterToLessStrictBridge{
    T,
    F<:MOI.VectorAffineFunction,
    G<:MOI.VectorAffineFunction,
    A
} <: IndicatorGreaterToLessBridge{T,F,G,A}
    constraint::CI{F,MOI.IndicatorSet{A,Strictly{T,MOI.LessThan{T}}}}
end

function MOIBC.map_function(::Type{<:IndicatorGreaterToLessBridge{T}}, func) where {T}
    # apply the operator only for the inner constraint part (here the second part)
    operate_vector_affine_function_part(-, T, func, 2)
end

function MOIBC.map_set(::Type{<:IndicatorGreaterToLessUnstrictBridge}, set::MOI.IndicatorSet{A,<:MOI.GreaterThan}) where A
    inner_set = set.set
    return MOI.IndicatorSet{A}(MOI.LessThan(-inner_set.lower))
end
function MOIBC.inverse_map_set(::Type{<:IndicatorGreaterToLessUnstrictBridge}, set::MOI.IndicatorSet{A,<:MOI.LessThan}) where A
    inner_set = set.set
    return MOI.IndicatorSet{A}(MOI.GreaterThan(-inner_set.upper))
end

function MOIBC.map_set(::Type{<:IndicatorGreaterToLessStrictBridge}, set::MOI.IndicatorSet{A,Strictly{T, MOI.GreaterThan{T}}}) where {A,T}
    inner_set = set.set.set
    return MOI.IndicatorSet{A}(Strictly(MOI.LessThan(-inner_set.lower)))
end
function MOIBC.inverse_map_set(::Type{<:IndicatorGreaterToLessStrictBridge}, set::MOI.IndicatorSet{A,Strictly{T, MOI.LessThan{T}}}) where {A,T}
    inner_set = set.set.set
    return MOI.IndicatorSet{A}(Strictly(MOI.GreaterThan(-inner_set.upper)))
end

function MOIB.added_constrained_variable_types(::Type{<:IndicatorGreaterToLessBridge})
    return []
end
function MOIB.added_constraint_types(
    ::Type{<:IndicatorGreaterToLessUnstrictBridge{T,F,G,A}},
) where {T,F,G,A}
    return [(F, MOI.IndicatorSet{A,MOI.LessThan{T}})]
end
function MOIB.added_constraint_types(
    ::Type{<:IndicatorGreaterToLessStrictBridge{T,F,G,A}},
) where {T,F,G,A}
    return [(F, MOI.IndicatorSet{A,Strictly{T, MOI.LessThan{T}}})]
end

function MOIBC.concrete_bridge_type(
    ::Type{<:IndicatorGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:MOI.IndicatorSet{A,MOI.GreaterThan{T}}}
    return IndicatorGreaterToLessUnstrictBridge{T,MOI.VectorAffineFunction{T},MOI.VectorAffineFunction{T},A}
end

function MOIBC.concrete_bridge_type(
    ::Type{<:IndicatorGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:MOI.IndicatorSet{A,Strictly{T, MOI.GreaterThan{T}}}}
    return IndicatorGreaterToLessStrictBridge{T,MOI.VectorAffineFunction{T},MOI.VectorAffineFunction{T},A}
end

function MOI.supports_constraint(
    ::Type{<:IndicatorGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:MOI.IndicatorSet{A,<:UnionGT{T}}}
    return true
end

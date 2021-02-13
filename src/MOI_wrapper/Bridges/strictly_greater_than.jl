struct StrictlyGreaterToStrictlyLessBridge{
    T,
    F<:MOI.AbstractScalarFunction,
    G<:MOI.AbstractScalarFunction,
} <: MOIBC.FlipSignBridge{T,Strictly{T,MOI.GreaterThan{T}},Strictly{T,MOI.LessThan{T}},F,G}
    constraint::CI{F,Strictly{T,MOI.LessThan{T}}}
end
function MOIBC.map_set(::Type{<:StrictlyGreaterToStrictlyLessBridge}, set::Strictly{T,MOI.GreaterThan{T}}) where T
    return Strictly(MOI.LessThan(-set.set.lower))
end
function MOIBC.inverse_map_set(::Type{<:StrictlyGreaterToStrictlyLessBridge}, set::Strictly{T,MOI.LessThan{T}}) where T
    return Strictly(MOI.GreaterThan(-set.set.upper))
end
function MOIBC.concrete_bridge_type(
    ::Type{<:StrictlyGreaterToStrictlyLessBridge{T}},
    G::Type{<:MOI.AbstractScalarFunction},
    ::Type{Strictly{T,MOI.GreaterThan{T}}},
) where {T}
    F = MOIU.promote_operation(-, T, G)
    return StrictlyGreaterToStrictlyLessBridge{T,F,G}
end

struct StrictlyGreaterToStrictlyLessBridge{
    T,
    F<:MOI.AbstractScalarFunction,
    G<:MOI.AbstractScalarFunction,
} <: MOIBC.FlipSignBridge{T,CPE.Strictly{MOI.GreaterThan{T},T},CPE.Strictly{MOI.LessThan{T}, T},F,G}
    constraint::CI{F,CPE.Strictly{MOI.LessThan{T}, T}}
end
function MOIB.map_set(::Type{<:StrictlyGreaterToStrictlyLessBridge}, set::CPE.Strictly{MOI.GreaterThan{T}, T}) where T
    return CPE.Strictly(MOI.LessThan(-set.set.lower))
end
function MOIB.inverse_map_set(::Type{<:StrictlyGreaterToStrictlyLessBridge}, set::CPE.Strictly{MOI.LessThan{T}, T}) where T
    return CPE.Strictly(MOI.GreaterThan(-set.set.upper))
end
function MOIBC.concrete_bridge_type(
    ::Type{<:StrictlyGreaterToStrictlyLessBridge{T}},
    G::Type{<:MOI.AbstractScalarFunction},
    ::Type{CPE.Strictly{MOI.GreaterThan{T}, T}},
) where {T}
    F = MOIU.promote_operation(-, T, G)
    return StrictlyGreaterToStrictlyLessBridge{T,F,G}
end

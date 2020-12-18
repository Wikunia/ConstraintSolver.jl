"""
    GreaterToLessBridge{T, F<:MOI.AbstractScalarFunction, G<:MOI.AbstractScalarFunction} <:
        FlipSignBridge{T, MOI.GreaterThan{T}, MOI.LessThan{T}, F, G}
Transforms a `G`-in-`GreaterThan{T}` constraint into an `F`-in-`LessThan{T}`
constraint.
"""
struct GreaterToLessBridge{
    T,
    F<:MOI.AbstractScalarFunction,
    G<:MOI.AbstractScalarFunction,
} <: MOI.Bridges.Constraint.FlipSignBridge{T,GreaterThan{T},LessThan{T},F,G}
    constraint::CI{F,LessThan{T}}
end
function MOI.Bridges.Constraint.map_set(::Type{<:GreaterToLessBridge}, set::GreaterThan)
    return LessThan(-set.lower, set.strict)
end
function MOI.Bridges.Constraint.inverse_map_set(::Type{<:GreaterToLessBridge}, set::LessThan)
    return GreaterThan(-set.upper, set.strict)
end
function MOI.Bridges.Constraint.concrete_bridge_type(
    ::Type{<:GreaterToLessBridge{T}},
    G::Type{<:MOI.AbstractScalarFunction},
    ::Type{GreaterThan{T}},
) where {T}
    F = MOIU.promote_operation(-, T, G)
    return GreaterToLessBridge{T,F,G}
end

function MOI.supports_constraint(::Type{GreaterToLessBridge},
                ::Type{JuMP.GenericAffExpr}, ::Type{GreaterThan})
    return true
end

function JuMP.build_constraint(_error::Function, func::JuMP.GenericAffExpr,
    set::GreaterThan)
    constraint = JuMP.ScalarConstraint(func, set)
    return JuMP.BridgeableConstraint(constraint, GreaterToLessBridge)
end

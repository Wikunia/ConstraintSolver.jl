struct IndicatorBridge{T, B<:MOIBC.SetMapBridge{T}, A, IS_MOI_OR_CS, S} <: MOIBC.AbstractBridge
    con_idx::CI
end

function MOI.supports_constraint(
    ::Type{<:IndicatorBridge{T, B}},
    ::Type{F},
    ::Type{<:Union{MOI.IndicatorSet{A,S}, CS.IndicatorSet{A,S}}}
) where {T, B, F<:MOI.VectorAffineFunction, A, S}
    is_supported = MOI.supports_constraint(B, MOIU.scalar_type(F), S)
    !is_supported && return false
    S <: AbstractBoolSet && return true

    concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    return supports_concreteB(concrete_B)
end

function MOIBC.concrete_bridge_type(
    ::Type{<:IndicatorBridge{T,B}},
    G::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,B,A,S,IS<:Union{MOI.IndicatorSet{A,S}, CS.IndicatorSet{A,S}}}
    if S <: AbstractBoolSet
        concrete_B = B
    else
        concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    end
    IS_MOI_OR_CS = IS <: MOI.IndicatorSet ? MOI.IndicatorSet : CS.IndicatorSet
    return IndicatorBridge{T,concrete_B,A,IS_MOI_OR_CS,S}
end

function MOIB.added_constraint_types(
    ::Type{<:IndicatorBridge{T,B,A,IS_MOI_OR_CS,S}}
) where {T,B,A,IS_MOI_OR_CS,S}
    if S <: AbstractBoolSet
        added_constraints = added_constraint_types(B, S)
    else
        added_constraints = MOIB.added_constraint_types(B)
    end
    return [(MOI.VectorAffineFunction{T}, IS_MOI_OR_CS{A,added_constraints[1][2]})]
end

function MOIB.added_constrained_variable_types(::Type{<:IndicatorBridge{T,B}}) where {T,B}
    return MOIB.added_constrained_variable_types(B)
end

function MOIBC.bridge_constraint(::Type{<:IndicatorBridge{T, B, A, IS_MOI_OR_CS, S}}, model, func, set) where {T, B, A, IS_MOI_OR_CS, S}
    f = MOIU.eachscalar(func)
    if S <: AbstractBoolSet
        new_func = MOIU.operate(vcat, T, f[1], map_function(B, f[2:end], set.set))
        new_inner_set = map_set(B, set.set)
    else
        new_func = MOIU.operate(vcat, T, f[1], MOIBC.map_function(B, f[2:end]))
        new_inner_set = MOIBC.map_set(B, set.set)
    end
    new_set = IS_MOI_OR_CS{A}(new_inner_set)
    return IndicatorBridge{T,B,A,IS_MOI_OR_CS,S}(MOI.add_constraint(model, new_func, new_set))
end

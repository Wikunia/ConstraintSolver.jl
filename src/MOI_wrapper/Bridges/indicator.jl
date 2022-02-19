struct IndicatorBridge{T, B<:MOIBC.SetMapBridge{T}, A, IS_MOI_OR_CS, F, S} <: MOIBC.AbstractBridge
    con_idx::CI
end

function MOI.supports_constraint(
    ::Type{<:IndicatorBridge{T, B}},
    ::Type{F},
    ::Type{MOI.Indicator{A,S}}
) where {T, B, F<:MOI.VectorAffineFunction, A, S}
    is_supported = MOI.supports_constraint(B, MOIU.scalar_type(F), S)
    !is_supported && return false
    S <: AbstractBoolSet && return true

    concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    return supports_concreteB(concrete_B)
end

function MOI.supports_constraint(
    ::Type{<:IndicatorBridge{T, B}},
    ::Type{F},
    ::Type{CS.Indicator{A,IF,S}}
) where {T, B, F<:MOI.VectorAffineFunction, A, IF, S}
    is_supported = MOI.supports_constraint(B, IF, S)
    !is_supported && return false
    S <: AbstractBoolSet && return true

    concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    return supports_concreteB(concrete_B)
end

function MOIBC.concrete_bridge_type(
    IB::Type{<:IndicatorBridge{T,B}},
    G::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,B,A,S,IS<:MOI.Indicator{A,S}}
    concrete_B = get_concrete_B(IB,S)
    return IndicatorBridge{T,concrete_B,A,MOI.Indicator,MOI.ScalarAffineFunction,S}
end

function MOIBC.concrete_bridge_type(
    IB::Type{<:IndicatorBridge{T,B}},
    G::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,B,A,S,IF,IS<:CS.Indicator{A,IF,S}}
    concrete_B = get_concrete_B(IB,S)
    return IndicatorBridge{T,concrete_B,A,CS.Indicator,IF,S}
end

function get_concrete_B(
    ::Type{<:IndicatorBridge{T,B}},
    S
) where {T,B}
    if S <: AbstractBoolSet
        return B
    else
        return MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    end
end

function MOIB.added_constraint_types(
    ::Type{<:IndicatorBridge{T,B,A,IS_MOI_OR_CS,F,S}}
) where {T,B,A,IS_MOI_OR_CS<:MOI.Indicator,F,S}
    added_constraints = added_constraint_types(B, S)
    return [(MOI.VectorAffineFunction{T}, MOI.Indicator{A,added_constraints[1][2]})]
end

function MOIB.added_constraint_types(
    ::Type{<:IndicatorBridge{T,B,A,IS_MOI_OR_CS,F,S}}
) where {T,B,A,IS_MOI_OR_CS<:CS.Indicator,F,S}
    added_constraints = added_constraint_types(B, S)
    return [(MOI.VectorAffineFunction{T}, CS.Indicator{A,F,added_constraints[1][2]})]
end


function MOIB.added_constrained_variable_types(::Type{<:IndicatorBridge{T,B}}) where {T,B}
    return MOIB.added_constrained_variable_types(B)
end

function MOIBC.bridge_constraint(::Type{<:IndicatorBridge{T, B, A, IS_MOI_OR_CS, F, S}}, model, func, set) where {T, B, A, IS_MOI_OR_CS<:MOI.Indicator, F, S}
    f = MOIU.eachscalar(func)
    new_func = MOIU.operate(vcat, T, f[1], map_function(B, f[2:end], set.set))
    new_inner_set = MOIB.map_set(B, set.set)
    new_set = MOI.Indicator{A}(new_inner_set)
    return IndicatorBridge{T,B,A,IS_MOI_OR_CS,F,S}(MOI.add_constraint(model, new_func, new_set))
end

function MOIBC.bridge_constraint(::Type{<:IndicatorBridge{T, B, A, IS_MOI_OR_CS, F, S}}, model, func, set) where {T, B, A, IS_MOI_OR_CS<:CS.Indicator, F, S}
    f = MOIU.eachscalar(func)
    new_func = MOIU.operate(vcat, T, f[1], map_function(B, f[2:end], set.set))
    new_inner_set = MOIB.map_set(B, set.set)
    new_set = CS.Indicator{A,F}(new_inner_set)
    return IndicatorBridge{T,B,A,IS_MOI_OR_CS,F,S}(MOI.add_constraint(model, new_func, new_set))
end


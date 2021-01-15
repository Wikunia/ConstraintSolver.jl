struct IndicatorBridge{T, B<:MOIBC.SetMapBridge{T}, A} <: MOIBC.AbstractBridge
    con_idx::CI
end

function MOI.supports_constraint(
    ::Type{<:IndicatorBridge{T, B}},
    ::Type{F},
    ::Type{<:MOI.IndicatorSet{A,S}}
) where {T, B, F<:MOI.VectorAffineFunction, A, S}
    is_supported = MOI.supports_constraint(B, MOIU.scalar_type(F), S)
    !is_supported && return false

    concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    added_constraints = MOIB.added_constraint_types(concrete_B)
    length(added_constraints) > 1 && return false
    # The inner constraint should not create any variable (might have unexpected consequences)
    return isempty(MOIB.added_constrained_variable_types(concrete_B))
end

function MOIBC.concrete_bridge_type(
    ::Type{<:IndicatorBridge{T,B}},
    G::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,B,A,S,IS<:MOI.IndicatorSet{A,S}}
    concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    return IndicatorBridge{T,concrete_B,A}
end

function MOIB.added_constraint_types(
    ::Type{<:IndicatorBridge{T,B,A}}
) where {T,B,A}
    added_constraints = MOIB.added_constraint_types(B)
    return [(MOI.VectorAffineFunction{T}, MOI.IndicatorSet{A,added_constraints[1][2]})]
end

function MOIB.added_constrained_variable_types(::Type{<:IndicatorBridge{T,B}}) where {T,B}
    return MOIB.added_constrained_variable_types(B)
end

function MOIBC.bridge_constraint(::Type{<:IndicatorBridge{T, B, A}}, model, func, set) where {T, B, A}
    f = MOIU.eachscalar(func)
    new_func = MOIU.operate(vcat, T, f[1], MOIBC.map_function(B, f[2]))
    new_inner_set = MOIBC.map_set(B, set.set)
    new_set = MOI.IndicatorSet{A}(new_inner_set)
    return IndicatorBridge{T,B,A}(MOI.add_constraint(model, new_func, new_set))
end

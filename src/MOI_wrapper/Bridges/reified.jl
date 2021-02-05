struct ReifiedBridge{T, B<:MOIBC.SetMapBridge{T}, A, S} <: MOIBC.AbstractBridge
    con_idx::CI
end

function MOI.supports_constraint(
    ::Type{<:ReifiedBridge{T, B}},
    ::Type{F},
    ::Type{<:CS.ReifiedSet{A,S}}
) where {T, B, F<:MOI.VectorAffineFunction, A, S}
    is_supported = MOI.supports_constraint(B, MOIU.scalar_type(F), S)
    !is_supported && return false
    S <: AndSet && return true

    concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    return supports_concreteB(concrete_B)
end

function MOIBC.concrete_bridge_type(
    ::Type{<:ReifiedBridge{T,B}},
    G::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,B,A,S,IS<:CS.ReifiedSet{A,S}}
    if S <: AndSet
        concrete_B = B
    else
        concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    end
    return ReifiedBridge{T,concrete_B,A,S}
end

function MOIB.added_constraint_types(
    ::Type{<:ReifiedBridge{T,B,A,S}}
) where {T,B,A,S}
    if S <: AndSet
        added_constraints = added_constraint_types(B, S)
    else
        added_constraints = MOIB.added_constraint_types(B)
    end
    return [(MOI.VectorAffineFunction{T}, CS.ReifiedSet{A,added_constraints[1][2]})]
end

function MOIB.added_constrained_variable_types(::Type{<:ReifiedBridge{T,B}}) where {T,B}
    return MOIB.added_constrained_variable_types(B)
end

function MOIBC.bridge_constraint(::Type{<:ReifiedBridge{T, B, A, S}}, model, func, set) where {T, B, A, S}
    f = MOIU.eachscalar(func)
    if S <: AndSet
        new_func = MOIU.operate(vcat, T, f[1], map_function(B, f[2:end], set.set))
        new_inner_set = map_set(B, set.set)
    else
        new_func = MOIU.operate(vcat, T, f[1], MOIBC.map_function(B, f[2:end]))
        new_inner_set = MOIBC.map_set(B, set.set)
    end
    new_set = CS.ReifiedSet{A,typeof(new_inner_set)}(new_inner_set, 1+MOI.dimension(new_inner_set))
    return ReifiedBridge{T,B,A,S}(MOI.add_constraint(model, new_func, new_set))
end

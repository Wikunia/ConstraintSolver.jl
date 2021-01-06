struct ReifiedGreaterToLessBridge{
    T,
    F<:MOI.VectorAffineFunction,
    G<:MOI.VectorAffineFunction,
    A
} <: MOIBC.FlipSignBridge{T,CS.ReifiedSet{A},CS.ReifiedSet{A},F,G}
    constraint::CI{F,CS.ReifiedSet{A,MOI.LessThan{T}}}
end

function MOIBC.map_function(::Type{<:ReifiedGreaterToLessBridge{T}}, func) where {T}
    # apply the operator only for the inner constraint part (here the second part)
    operate_vector_affine_function_part(-, T, func, 2)
end

function MOIBC.map_set(::Type{<:ReifiedGreaterToLessBridge}, set::CS.ReifiedSet{A,<:MOI.GreaterThan{T}}) where {A,T}
    inner_set = set.set
    return CS.ReifiedSet{A, MOI.LessThan{T}}(MOI.LessThan(-inner_set.lower), set.dimension)
end
function MOIBC.inverse_map_set(::Type{<:ReifiedGreaterToLessBridge}, set::CS.ReifiedSet{A,<:MOI.LessThan{T}}) where {A,T}
    inner_set = set.set
    return CS.ReifiedSet{A, MOI.GreaterThan{T}}(MOI.GreaterThan(-inner_set.upper), set.dimension)
end

function MOIB.added_constrained_variable_types(::Type{<:ReifiedGreaterToLessBridge})
    return []
end
function MOIB.added_constraint_types(
    ::Type{<:ReifiedGreaterToLessBridge{T,F,G,A}},
) where {T,F,G,A}
    return [(F, CS.ReifiedSet{A,MOI.LessThan{T}})]
end

function MOIBC.concrete_bridge_type(
    ::Type{<:ReifiedGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:CS.ReifiedSet{A,MOI.GreaterThan{T}}}
    return ReifiedGreaterToLessBridge{T,MOI.VectorAffineFunction{T},MOI.VectorAffineFunction{T},A}
end

function MOI.supports_constraint(
    ::Type{<:ReifiedGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:CS.ReifiedSet{A,MOI.GreaterThan{T}}}
    return true
end

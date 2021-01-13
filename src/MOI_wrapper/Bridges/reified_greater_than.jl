"""
    General FlipSignBridge for both strict and unstrict
"""
abstract type
    ReifiedGreaterToLessBridge{
        T,F,G,A
    } <: MOIBC.FlipSignBridge{T,ReifiedSet{A},ReifiedSet{A},F,G}
end

function MOIBC.map_function(::Type{<:ReifiedGreaterToLessBridge{T}}, func) where {T}
    # apply the operator only for the inner constraint part (here the second part)
    operate_vector_affine_function_part(-, T, func, 2)
end

function MOIB.added_constrained_variable_types(::Type{<:ReifiedGreaterToLessBridge})
    return []
end

function MOI.supports_constraint(
    ::Type{<:ReifiedGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:CS.ReifiedSet{A,<:UnionGT{T}}}
    return true
end

#=
    Unstrict version
=#
struct ReifiedGreaterToLessUnstrictBridge{
    T,
    F<:MOI.VectorAffineFunction,
    G<:MOI.VectorAffineFunction,
    A
} <: ReifiedGreaterToLessBridge{T,F,G,A}
    constraint::CI{F,ReifiedSet{A,MOI.LessThan{T}}}
end

function MOIBC.map_set(::Type{<:ReifiedGreaterToLessUnstrictBridge}, set::CS.ReifiedSet{A,<:MOI.GreaterThan{T}}) where {A,T}
    inner_set = set.set
    return CS.ReifiedSet{A, MOI.LessThan{T}}(MOI.LessThan(-inner_set.lower), set.dimension)
end
function MOIBC.inverse_map_set(::Type{<:ReifiedGreaterToLessUnstrictBridge}, set::CS.ReifiedSet{A,<:MOI.LessThan{T}}) where {A,T}
    inner_set = set.set
    return CS.ReifiedSet{A, MOI.GreaterThan{T}}(MOI.GreaterThan(-inner_set.upper), set.dimension)
end


function MOIB.added_constraint_types(
    ::Type{<:ReifiedGreaterToLessUnstrictBridge{T,F,G,A}},
) where {T,F,G,A}
    return [(F, CS.ReifiedSet{A,MOI.LessThan{T}})]
end
function MOIBC.concrete_bridge_type(
    ::Type{<:ReifiedGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:CS.ReifiedSet{A,MOI.GreaterThan{T}}}
    return ReifiedGreaterToLessUnstrictBridge{T,MOI.VectorAffineFunction{T},MOI.VectorAffineFunction{T},A}
end


#=
    Strict version
=#
struct ReifiedGreaterToLessStrictBridge{
    T,
    F<:MOI.VectorAffineFunction,
    G<:MOI.VectorAffineFunction,
    A
} <: ReifiedGreaterToLessBridge{T,F,G,A}
    constraint::CI{F,ReifiedSet{A,Strictly{T, MOI.LessThan{T}}}}
end

function MOIBC.map_set(::Type{<:ReifiedGreaterToLessStrictBridge}, set::CS.ReifiedSet{A,<:Strictly{T,MOI.GreaterThan{T}}}) where {A,T}
    inner_set = set.set.set
    return CS.ReifiedSet{A, Strictly{T,MOI.LessThan{T}}}(Strictly(MOI.LessThan(-inner_set.lower)), set.dimension)
end
function MOIBC.inverse_map_set(::Type{<:ReifiedGreaterToLessStrictBridge}, set::CS.ReifiedSet{A,<:Strictly{T,MOI.LessThan{T}}}) where {A,T}
    inner_set = set.set.set
    return CS.ReifiedSet{A, Strictly{T,MOI.GreaterThan{T}}}(Strictly(MOI.GreaterThan(-inner_set.upper)), set.dimension)
end


function MOIB.added_constraint_types(
    ::Type{<:ReifiedGreaterToLessStrictBridge{T,F,G,A}},
) where {T,F,G,A}
    return [(F, CS.ReifiedSet{A,Strictly{T,MOI.LessThan{T}}})]
end
function MOIBC.concrete_bridge_type(
    ::Type{<:ReifiedGreaterToLessBridge{T}},
    ::Type{<:MOI.VectorAffineFunction},
    ::Type{IS},
) where {T,A,IS<:CS.ReifiedSet{A,Strictly{T,MOI.GreaterThan{T}}}}
    return ReifiedGreaterToLessStrictBridge{T,MOI.VectorAffineFunction{T},MOI.VectorAffineFunction{T},A}
end

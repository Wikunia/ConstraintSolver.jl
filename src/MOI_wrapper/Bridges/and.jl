struct AndBridge{T, B<:MOIBC.SetMapBridge{T}, P, F1, F2, F1dim, F2dim, S1, S2} <: MOIBC.SetMapBridge{T, S2, S1, F2, F1}
    con_idx::CI
end

function MOI.supports_constraint(
    ::Type{<:AndBridge{T, B, Val{:LHS}}},
    ::Type{<:MOI.AbstractFunction},
    ::Type{<:CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T, B, F1, F2, F1dim, F2dim, S1, S2}
    is_supported = MOI.supports_constraint(B, F1, S1)
    !is_supported && return false

    concrete_B = MOIBC.concrete_bridge_type(B, F1, S1)
    return supports_concreteB(concrete_B)
end

function MOIBC.concrete_bridge_type(
    ::Type{<:AndBridge{T,B,P}},
    F::Type{<:MOI.AbstractFunction},
    S::Type{<:CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}},
) where {T,B,P<:Val{:LHS},F1,F2,F1dim,F2dim,S1,S2} 
    concrete_B = MOIBC.concrete_bridge_type(B, F1, S1)
    return AndBridge{T,concrete_B,P,F1,F2,F1dim, F2dim, S1,S2}
end

function MOIB.added_constraint_types(
    ::Type{<:AndBridge{T,B,P,F1,F2,F1dim,F2dim,S1,S2}}
) where {T,B,P<:Val{:LHS},F1,F2,F1dim,F2dim,S1,S2}
    added_constraints = MOIB.added_constraint_types(B)
    func = added_constraints[1][1]
    set = added_constraints[1][2]
    return [(MOI.VectorAffineFunction{T}, CS.AndSet{func, F2, F1dim, F2dim, set, S2})]
end

function MOIB.added_constrained_variable_types(::Type{<:AndBridge{T,B}}) where {T,B}
    return MOIB.added_constrained_variable_types(B)
end

function MOIBC.map_function(::Type{<:AndBridge{T, B, P, F1, F2, F1dim, F2dim}}, fct) where {T, B, P<:Val{:LHS}, F1, F2, F1dim, F2dim}
    f = MOIU.eachscalar(fct)
    lhs_fct = f[1:get_value(F1dim)]
    rhs_fct = f[end-get_value(F2dim)+1:end]
    mapped_lhs_fct = MOIBC.map_function(B, lhs_fct)
    # update the output indices of the rhs_fct
    rhs_terms = Vector{MOI.VectorAffineTerm{T}}()
    for term in rhs_fct.terms
        push!(rhs_terms, MOI.VectorAffineTerm{T}(term.output_index + get_value(F1dim), term.scalar_term))
    end
    rhs_fct = MOI.VectorAffineFunction(rhs_terms, rhs_fct.constants)
    return MOI.VectorAffineFunction([mapped_lhs_fct.terms..., rhs_fct.terms...],  [mapped_lhs_fct.constants..., rhs_fct.constants...])
end

function MOIBC.map_set(::Type{<:AndBridge{T, B, P, F1, F2}}, set) where {T, B, P<:Val{:LHS}, F1, F2}
    lhs_mapped = MOIBC.map_set(B, set.lhs_set)
    return AndSet{F1,F2}(lhs_mapped, set.rhs_set)
end

# TODO: Needs implementation one day ;)
#=
function MOIBC.bridge_constraint(::Type{<:AndBridge{T, B, P}}, model, func, set::AndSet) where {T, B, P<:Val{:LHS}}
    
end
=#

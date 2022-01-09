struct ComplementBridge{T, B<:MOIBC.SetMapBridge{T}, F, S} <: MOIBC.SetMapBridge{T, MOI.AbstractVectorSet, S, MOI.AbstractFunction, MOI.AbstractFunction}
    con_idx::CI
end

function MOI.supports_constraint(
    ::Type{<:ComplementBridge{T, B}},
    ::Type{F},
    ::Type{<:CS.ComplementSet{CF,S}}
) where {T, B, F<:MOI.AbstractFunction, CF, S}
    if CF <: MOI.ScalarAffineFunction
        is_supported = MOI.supports_constraint(B, CF, S)
    else
        is_supported = MOI.supports_constraint(B, MOIU.scalar_type(CF), S)
    end
    !is_supported && return false
    S <: AbstractBoolSet && return true

    concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    supported = supports_concreteB(concrete_B)
    return supported
end

function MOIBC.concrete_bridge_type(
    ::Type{<:ComplementBridge{T,B}},
    G::Type{<:MOI.AbstractFunction},
    ::Type{<:CS.ComplementSet{F,S}},
) where {T,B,F,S}
    if S <: AbstractBoolSet
        concrete_B = B
    else
        concrete_B = MOIBC.concrete_bridge_type(B, MOI.ScalarAffineFunction{T}, S)
    end
    return ComplementBridge{T,concrete_B,F,S}
end

function MOIB.added_constraint_types(
    ::Type{<:ComplementBridge{T,B,F,S}}
) where {T,B,F,S}
    if S <: AbstractBoolSet
        added_constraints = added_constraint_types(B, S)
    else
        added_constraints = MOIB.added_constraint_types(B)
    end
    return [(F, CS.ComplementSet{F,added_constraints[1][2]})]
end

function MOIB.added_constrained_variable_types(::Type{<:ComplementBridge{T,B}}) where {T,B}
    return MOIB.added_constrained_variable_types(B)
end

function MOIBC.bridge_constraint(::Type{<:ComplementBridge{T, B, F, S}}, model, fct, set) where {T, B, F, S}
    new_fct = map_function(B, fct, set.set)
    new_inner_set = MOIB.map_set(B, set.set)
    new_set = CS.ComplementSet{F}(new_inner_set)
    if (new_fct isa SAF) && F <: SAF
        new_fct = get_saf(new_fct)
    end
    return ComplementBridge{T,B,F,S}(MOI.add_constraint(model, new_fct, new_set))
end

function map_function(
    bridge::Type{<:ComplementBridge{T, B}},
    fct,
    set::ComplementSet{F,S}
) where {T,B,F,S<:AbstractBoolSet}
    return map_function(B, fct, set.set)
end

function MOIB.map_function(
    bridge::Type{<:ComplementBridge{T, B}},
    fct,
) where {T,B}
    return MOIB.map_function(B, fct)
end

function MOIB.map_set(
    bridge::Type{<:ComplementBridge{T, B}},
    set::ComplementSet{F},
) where {T,B,F}
    mapped_set = MOIB.map_set(B, set.set)
    return ComplementSet{F}(mapped_set)
end
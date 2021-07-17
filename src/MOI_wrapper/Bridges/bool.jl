struct BoolBridge{T, B<:MOIBC.SetMapBridge{T}, F1, F2, S1, S2} <: MOIBC.SetMapBridge{T, S2, S1, F2, F1}
    con_idx::CI
end

function MOI.supports_constraint(
    bridge::Type{<:BoolBridge{T, B}},
    fct::Type{<:MOI.AbstractFunction},
    set::Type{<:CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T, B, F1, F2, F1dim, F2dim, S1, S2}
    # check whether there is at least one constraint which is supported by the inner bridge
    supported = uses_bool_inner(B, fct, set) 
    return supported
end

function uses_bool_inner(
    inner_bridge_type, 
    fct::Type{<:MOI.AbstractFunction},
    set::Type{<:CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {F1, F2, F1dim, F2dim, S1, S2}
    return uses_bool_inner(inner_bridge_type, F1, S1) || uses_bool_inner(inner_bridge_type, F2, S2) 
end

function uses_bool_inner(
    inner_bridge_type, 
    F::Type{<:MOI.AbstractFunction},
    S
) 
    return MOI.supports_constraint(inner_bridge_type, F, S)
end

function added_constraint_types(
    bridge::Type{<:BoolBridge{T, B}},
    ::Type{<:CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T,B, F1, F2, F1dim, F2dim, S1, S2}
    get_bridged_and_set(bridge,F1,F2,F1dim,F2dim,S1,S2)
end

function MOIBC.concrete_bridge_type(
    ::Type{<:BoolBridge{T,B}},
    G::Type{<:MOI.AbstractFunction},
    ::Type{<:CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T,B,F1, F2, F1dim, F2dim, S1, S2}
    return BoolBridge{T,B,F1,F2,S1,S2}
end

function MOIBC.bridge_constraint(bridge::Type{<:BoolBridge{T, B, F1, F2, S1, S2}}, model, fct, set::CS.AbstractBoolSet) where {T, B, F1, F2, S1, S2}
    new_fct = map_function(bridge, fct, set)
    new_set = MOIBC.map_set(bridge, set)
    return BoolBridge{T,B,F1,F2,S1,S2}(MOI.add_constraint(model, new_fct, new_set))
end

function unpack_constraint_types(ct1, ct2)
    new_F1 = ct1[1][1]
    new_F2 = ct2[1][1]
    new_S1 = ct1[1][2]
    new_S2 = ct2[1][2]  
    return new_F1, new_F2, new_S1, new_S2 
end

function how_supported(
    B::Type{<:MOIBC.SetMapBridge{T}}, 
    F, S
) where {T}
    supported_by_B = MOI.supports_constraint(B, F, S)
    if !supported_by_B
        return true, nothing
    elseif supported_by_B
        return false, B
    end
end

function get_constraint_types(
    B::Type{<:MOIBC.SetMapBridge{T}}, 
    F, S
) where {T}
    direct_support, inner_bridge = how_supported(B, F, S)
    if direct_support
        return [(F,S)]
    else
        return MOIB.added_constraint_types(inner_bridge, F, S)
    end
end

function get_mapped_fct(
    B::Type{<:MOIBC.SetMapBridge{T}}, 
    F, S,
    fct,
) where {T}
    direct_support, inner_bridge = how_supported(B, F, S)
    if direct_support
        return fct
    else
        return MOIBC.map_function(inner_bridge, fct)
    end
end

function get_mapped_set(
    B::Type{<:MOIBC.SetMapBridge{T}}, 
    F, S,
    set,
) where {T}
    direct_support, inner_bridge = how_supported(B, F, S)
    if direct_support
        return set
    else
        return MOIBC.map_set(inner_bridge, set)
    end
end

function get_bridged_and_set(
    bridge::Type{<:BoolBridge{T, B}},
    F1::Type{<:MOI.AbstractFunction},
    F2::Type{<:MOI.AbstractFunction},
    F1dim,
    F2dim,
    S1::Type{<:AbstractBoolSet{F11,F12,F11dim,F12dim,S11,S12}},
    S2::Type{<:AbstractBoolSet{F21,F22,F21dim,F22dim,S21,S22}}
) where {T, B, F11, F12,F11dim,F12dim, S11, S12, F21, F22, F21dim,F22dim, S21, S22}
    lhs_constraint_types = get_bridged_and_set(bridge, F11, F12, F11dim, F12dim, S11, S12)
    rhs_constraint_types = get_bridged_and_set(bridge, F21, F22, F21dim, F22dim, S21, S22)
    new_F1, new_F2, new_S1, new_S2 = unpack_constraint_types(lhs_constraint_types, rhs_constraint_types)
    return [(MOI.VectorAffineFunction{T},AbstractBoolSet{new_F1,new_F2,F1dim,F2dim,new_S1,new_S2})]
end

function get_bridged_and_set(
    bridge::Type{<:BoolBridge{T, B}},
    F1::Type{<:MOI.AbstractFunction},
    F2::Type{<:MOI.AbstractFunction},
    F1dim,
    F2dim,
    S1::Type{<:AbstractBoolSet{F11,F12,F11dim,F12dim,S11,S12}},
    S2
) where {T, B, F11, F12, F11dim, F12dim, S11, S12}
    lhs_constraint_types = get_bridged_and_set(bridge, F11, F12, F11dim, F12dim, S11, S12)  
    rhs_constraint_types = get_constraint_types(B, F2, S2)
    new_F1, new_F2, new_S1, new_S2 = unpack_constraint_types(lhs_constraint_types, rhs_constraint_types)
    return [(MOI.VectorAffineFunction{T},AbstractBoolSet{new_F1,new_F2,F1dim,F2dim,new_S1,new_S2})]
end

function get_bridged_and_set(
    bridge::Type{<:BoolBridge{T, B}},
    F1::Type{<:MOI.AbstractFunction},
    F2::Type{<:MOI.AbstractFunction},
    F1dim,
    F2dim,
    S1,
    S2::Type{<:AbstractBoolSet{F21,F22,F21dim,F22dim,S21,S22}}
) where {T, B, F21, F22, F21dim, F22dim, S21, S22}
    lhs_constraint_types = get_constraint_types(B, F1, S1)
    rhs_constraint_types = get_bridged_and_set(bridge, F21, F22, F21dim, F22dim, S21, S22)
    new_F1, new_F2, new_S1, new_S2 = unpack_constraint_types(lhs_constraint_types, rhs_constraint_types)
    return [(MOI.VectorAffineFunction{T},AbstractBoolSet{new_F1,new_F2,F1dim,F2dim,new_S1,new_S2})]
end

function get_bridged_and_set(
    bridge::Type{<:BoolBridge{T, B}},
    F1::Type{<:MOI.AbstractFunction},
    F2::Type{<:MOI.AbstractFunction},
    F1dim,
    F2dim,
    S1,
    S2,
) where {T, B}
    lhs_constraint_types = get_constraint_types(B, F1, S1)
    rhs_constraint_types = get_constraint_types(B, F2, S2)
    new_F1, new_F2, new_S1, new_S2 = unpack_constraint_types(lhs_constraint_types, rhs_constraint_types)
    return [(MOI.VectorAffineFunction{T}, AbstractBoolSet{new_F1,new_F2,F1dim,F2dim,new_S1,new_S2})]
end

function map_function(
    bridge::Type{<:BoolBridge{T, B}},
    fct,
    set::CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B,F1,F2,F1dim,F2dim,S1<:AbstractBoolSet,S2<:AbstractBoolSet}
    f = MOIU.eachscalar(fct)
    lhs_fct = map_function(bridge, f[1:get_value(F1dim)], set.lhs_set)
    rhs_fct = map_function(bridge, f[end-get_value(F2dim)+1:end], set.rhs_set)
    return MOIU.operate(vcat, T, lhs_fct, rhs_fct)
end

function map_function(
    bridge::Type{<:BoolBridge{T, B}},
    fct,
    set::CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B,F1,F2,F1dim,F2dim,S1<:AbstractBoolSet,S2}
    f = MOIU.eachscalar(fct)
    lhs_fct = map_function(bridge, f[1:get_value(F1dim)], set.lhs_set)
    rhs_fct = get_mapped_fct(B, F2, S2, f[end-get_value(F2dim)+1:end])
    return MOIU.operate(vcat, T, lhs_fct, rhs_fct)
end

function map_function(
    bridge::Type{<:BoolBridge{T, B}},
    fct,
    set::CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B,F1,F2,F1dim,F2dim,S1,S2<:AbstractBoolSet}
    f = MOIU.eachscalar(fct)
    lhs_fct = get_mapped_fct(B, F1, S1, f[1:get_value(F1dim)])
    rhs_fct = map_function(bridge, f[end-get_value(F2dim)+1:end], set.rhs_set)
    return MOIU.operate(vcat, T, lhs_fct, rhs_fct)
end

function map_function(
    bridge::Type{<:BoolBridge{T, B}},
    fct,
    set::CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B,F1,F2,F1dim,F2dim,S1,S2}
    f = MOIU.eachscalar(fct)
    lhs_fct = get_mapped_fct(B, F1, S1, f[1:get_value(F1dim)])
    rhs_fct = get_mapped_fct(B, F2, S2, f[end-get_value(F2dim)+1:end])
    return MOIU.operate(vcat, T, lhs_fct, rhs_fct)
end

##########################

function MOIBC.map_set(
    bridge::Type{<:BoolBridge{T, B}},
    set::CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B,F1,F2,F1dim,F2dim,S1<:AbstractBoolSet,S2<:AbstractBoolSet}
    lhs_set = MOIBC.map_set(bridge, set.lhs_set)
    rhs_set = MOIBC.map_set(bridge, set.rhs_set)
    return typeof_without_params(set){F1,F2}(lhs_set, rhs_set)
end

function MOIBC.map_set(
    bridge::Type{<:BoolBridge{T, B}},
    set::CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B,F1,F2,F1dim,F2dim,S1<:AbstractBoolSet,S2}
    lhs_set = MOIBC.map_set(bridge, set.lhs_set)
    rhs_set = get_mapped_set(B, F2, S2, set.rhs_set)
    return typeof_without_params(set){F1,F2}(lhs_set, rhs_set)
end

function MOIBC.map_set(
    bridge::Type{<:BoolBridge{T, B}},
    set::CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B,F1,F2,F1dim,F2dim,S1,S2<:AbstractBoolSet}
    lhs_set = get_mapped_set(B, F1, S1, set.lhs_set)
    rhs_set = MOIBC.map_set(bridge, set.rhs_set)
    return typeof_without_params(set){F1,F2}(lhs_set, rhs_set)
end

function MOIBC.map_set(
    bridge::Type{<:BoolBridge{T, B}},
    set::CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B,F1,F2,F1dim,F2dim,S1,S2}  
    lhs_set = get_mapped_set(B, F1, S1, set.lhs_set)
    rhs_set = get_mapped_set(B, F2, S2, set.rhs_set)

    return typeof_without_params(set){F1,F2}(lhs_set, rhs_set)
end

struct AndBridge{T, B1<:MOIBC.SetMapBridge{T}, B2<:MOIBC.SetMapBridge{T}, F1, F2, S1, S2} <: MOIBC.SetMapBridge{T, S2, S1, F2, F1}
    con_idx::CI
end

function MOI.supports_constraint(
    bridge::Type{<:AndBridge{T, B1, B2}},
    fct::Type{<:MOI.AbstractFunction},
    set::Type{<:CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T, B1, B2, F1, F2, F1dim, F2dim, S1<:AndSet, S2<:AndSet}
    return MOI.supports_constraint(bridge, F1, S1) && MOI.supports_constraint(bridge, F2, S2)
end

function MOI.supports_constraint(
    bridge::Type{<:AndBridge{T, B1, B2}},
    fct::Type{<:MOI.AbstractFunction},
    set::Type{<:CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T, B1, B2, F1, F2, F1dim, F2dim, S1<:AndSet, S2}
    direct_support, inner_bridge = how_supported(B1, B2, F2, S2)
    if direct_support || inner_bridge !== nothing
        return MOI.supports_constraint(bridge, F1, S1)
    end
end

function MOI.supports_constraint(
    bridge::Type{<:AndBridge{T, B1, B2}},
    fct::Type{<:MOI.AbstractFunction},
    set::Type{<:CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T, B1, B2, F1, F2, F1dim, F2dim, S1, S2<:AndSet}
    direct_support, inner_bridge = how_supported(B1, B2, F1, S1)
    if direct_support || inner_bridge !== nothing
        return MOI.supports_constraint(bridge, F2, S2)
    end
end

function MOI.supports_constraint(
    bridge::Type{<:AndBridge{T, B1, B2}},
    fct::Type{<:MOI.AbstractFunction},
    set::Type{<:CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T, B1, B2, F1, F2, F1dim, F2dim, S1, S2}
    direct_support, inner_bridge = how_supported(B1, B2, F1, S1)
    if !direct_support && inner_bridge === nothing
        return false
    end
    direct_support, inner_bridge = how_supported(B1, B2, F2, S2)
    if !direct_support && inner_bridge === nothing
        return false
    end
    return true
end

function added_constraint_types(
    bridge::Type{<:AndBridge{T, B1, B2}},
    ::Type{<:CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}}
) where {T,B1,B2,F1, F2, F1dim, F2dim, S1, S2}
    set = get_bridged_and_set(bridge,F1,F2,F1dim,F2dim,S1,S2)
end

function unpack_constraint_types(ct1, ct2)
    new_F1 = ct1[1][1]
    new_F2 = ct2[1][1]
    new_S1 = ct1[1][2]
    new_S2 = ct2[1][2]  
    return new_F1, new_F2, new_S1, new_S2 
end

function how_supported(
    B1::Type{<:MOIBC.SetMapBridge{T}}, 
    B2::Type{<:MOIBC.SetMapBridge{T}},
    F, S
) where {T}
    supported_by_B1 = MOI.supports_constraint(B1, F, S)
    supported_by_B2 = MOI.supports_constraint(B2, F, S)
    if !supported_by_B1 && !supported_by_B2
        return true, nothing
    elseif supported_by_B1
        return false, B1
    elseif supported_by_B2
        return false, B2
    else 
        return false, nothing
    end
end

function get_constraint_types(
    B1::Type{<:MOIBC.SetMapBridge{T}}, 
    B2::Type{<:MOIBC.SetMapBridge{T}},
    F, S
) where {T}
    direct_support, inner_bridge = how_supported(B1, B2, F, S)
    if direct_support
        return [(F,S)]
    else
        return MOIB.added_constraint_types(inner_bridge, F, S)
    end
end

function get_mapped_fct(
    B1::Type{<:MOIBC.SetMapBridge{T}}, 
    B2::Type{<:MOIBC.SetMapBridge{T}},
    F, S,
    fct,
) where {T}
    direct_support, inner_bridge = how_supported(B1, B2, F, S)
    if direct_support
        return fct
    else
        return MOIBC.map_function(inner_bridge, fct)
    end
end

function get_mapped_set(
    B1::Type{<:MOIBC.SetMapBridge{T}}, 
    B2::Type{<:MOIBC.SetMapBridge{T}},
    F, S,
    set,
) where {T}
    direct_support, inner_bridge = how_supported(B1, B2, F, S)
    if direct_support
        return set
    else
        return MOIBC.map_set(inner_bridge, set)
    end
end

function get_bridged_and_set(
    bridge::Type{<:AndBridge{T, B1, B2}},
    F1::Type{<:MOI.AbstractFunction},
    F2::Type{<:MOI.AbstractFunction},
    F1dim,
    F2dim,
    S1::Type{<:AndSet{F11,F12,F11dim,F12dim,S11,S12}},
    S2::Type{<:AndSet{F21,F22,F21dim,F22dim,S21,S22}}
) where {T, B1, B2, F11, F12,F11dim,F12dim, S11, S12, F21, F22, F21dim,F22dim, S21, S22}
    lhs_constraint_types = get_bridged_and_set(bridge, F11, F12, F11dim, F12dim, S11, S12)
    rhs_constraint_types = get_bridged_and_set(bridge, F21, F22, F21dim, F22dim, S21, S22)
    new_F1, new_F2, new_S1, new_S2 = unpack_constraint_types(lhs_constraint_types, rhs_constraint_types)
    return [(MOI.VectorAffineFunction{T},AndSet{new_F1,new_F2,F1dim,F2dim,new_S1,new_S2})]
end

function get_bridged_and_set(
    bridge::Type{<:AndBridge{T, B1, B2}},
    F1::Type{<:MOI.AbstractFunction},
    F2::Type{<:MOI.AbstractFunction},
    F1dim,
    F2dim,
    S1::Type{<:AndSet{F11,F12,F11dim,F12dim,S11,S12}},
    S2
) where {T, B1, B2, F11, F12, F11dim, F12dim, S11, S12}
    lhs_constraint_types = get_bridged_and_set(bridge, F11, F12, F11dim, F12dim, S11, S12)  
    rhs_constraint_types = get_constraint_types(B1, B2, F2, S2)
    new_F1, new_F2, new_S1, new_S2 = unpack_constraint_types(lhs_constraint_types, rhs_constraint_types)
    return [(MOI.VectorAffineFunction{T},AndSet{new_F1,new_F2,F1dim,F2dim,new_S1,new_S2})]
end

function get_bridged_and_set(
    bridge::Type{<:AndBridge{T, B1, B2}},
    F1::Type{<:MOI.AbstractFunction},
    F2::Type{<:MOI.AbstractFunction},
    F1dim,
    F2dim,
    S1,
    S2::Type{<:AndSet{F21,F22,F21dim,F22dim,S21,S22}}
) where {T, B1, B2, F21, F22, F21dim, F22dim, S21, S22}
    lhs_constraint_types = get_constraint_types(B1, B2, F1, S1)
    rhs_constraint_types = get_bridged_and_set(bridge, F21, F22, F21dim, F22dim, S21, S22)
    new_F1, new_F2, new_S1, new_S2 = unpack_constraint_types(lhs_constraint_types, rhs_constraint_types)
    return [(MOI.VectorAffineFunction{T},AndSet{new_F1,new_F2,F1dim,F2dim,new_S1,new_S2})]
end

function get_bridged_and_set(
    bridge::Type{<:AndBridge{T, B1, B2}},
    F1::Type{<:MOI.AbstractFunction},
    F2::Type{<:MOI.AbstractFunction},
    F1dim,
    F2dim,
    S1,
    S2,
) where {T, B1, B2}
    lhs_constraint_types = get_constraint_types(B1, B2, F1, S1)
    rhs_constraint_types = get_constraint_types(B1, B2, F2, S2)
    new_F1, new_F2, new_S1, new_S2 = unpack_constraint_types(lhs_constraint_types, rhs_constraint_types)
    return [(MOI.VectorAffineFunction{T}, AndSet{new_F1,new_F2,F1dim,F2dim,new_S1,new_S2})]
end

function map_function(
    bridge::Type{<:AndBridge{T, B1, B2}},
    fct,
    set::CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B1,B2,F1,F2,F1dim,F2dim,S1<:AndSet,S2<:AndSet}
    f = MOIU.eachscalar(fct)
    lhs_fct = map_function(bridge, f[1:get_value(F1dim)], set.lhs_set)
    rhs_fct = map_function(bridge, f[end-get_value(F2dim)+1:end], set.rhs_set)
    return MOIU.operate(vcat, T, lhs_fct, rhs_fct)
end

function map_function(
    bridge::Type{<:AndBridge{T, B1, B2}},
    fct,
    set::CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B1,B2,F1,F2,F1dim,F2dim,S1<:AndSet,S2}
    f = MOIU.eachscalar(fct)
    lhs_fct = map_function(bridge, f[1:get_value(F1dim)], set.lhs_set)
    rhs_fct = get_mapped_fct(B1, B2, F2, S2, f[end-get_value(F2dim)+1:end])
    return MOIU.operate(vcat, T, lhs_fct, rhs_fct)
end

function map_function(
    bridge::Type{<:AndBridge{T, B1, B2}},
    fct,
    set::CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B1,B2,F1,F2,F1dim,F2dim,S1,S2<:AndSet}
    f = MOIU.eachscalar(fct)
    lhs_fct = get_mapped_fct(B1, B2, F1, S1, f[1:get_value(F1dim)])
    rhs_fct = map_function(bridge, f[end-get_value(F2dim)+1:end], set.rhs_set)
    return MOIU.operate(vcat, T, lhs_fct, rhs_fct)
end

function map_function(
    bridge::Type{<:AndBridge{T, B1, B2}},
    fct,
    set::CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B1,B2,F1,F2,F1dim,F2dim,S1,S2}
    f = MOIU.eachscalar(fct)
    lhs_fct = get_mapped_fct(B1, B2, F1, S1, f[1:get_value(F1dim)])
    rhs_fct = get_mapped_fct(B1, B2, F2, S2, f[end-get_value(F2dim)+1:end])
    return MOIU.operate(vcat, T, lhs_fct, rhs_fct)
end

##########################

function map_set(
    bridge::Type{<:AndBridge{T, B1, B2}},
    set::CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B1,B2,F1,F2,F1dim,F2dim,S1<:AndSet,S2<:AndSet}
    lhs_set = map_set(bridge, set.lhs_set)
    rhs_set = map_set(bridge, set.rhs_set)
    return AndSet{F1,F2}(lhs_set, rhs_set)
end

function map_set(
    bridge::Type{<:AndBridge{T, B1, B2}},
    set::CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B1,B2,F1,F2,F1dim,F2dim,S1<:AndSet,S2}
    lhs_set = map_set(bridge, set.lhs_set)
    rhs_set = get_mapped_set(B1, B2, F2, S2, set.rhs_set)
    return AndSet{F1,F2}(lhs_set, rhs_set)
end

function map_set(
    bridge::Type{<:AndBridge{T, B1, B2}},
    set::CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B1,B2,F1,F2,F1dim,F2dim,S1,S2<:AndSet}
    lhs_set = get_mapped_set(B1, B2, F1, S1, set.lhs_set)
    rhs_set = map_set(bridge, set.rhs_set)
    return AndSet{F1,F2}(lhs_set, rhs_set)
end

function map_set(
    bridge::Type{<:AndBridge{T, B1, B2}},
    set::CS.AndSet{F1,F2,F1dim,F2dim,S1,S2}
) where {T,B1,B2,F1,F2,F1dim,F2dim,S1,S2}
    lhs_set = get_mapped_set(B1, B2, F1, S1, set.lhs_set)
    rhs_set = get_mapped_set(B1, B2, F2, S2, set.rhs_set)
    return AndSet{F1,F2}(lhs_set, rhs_set)
end

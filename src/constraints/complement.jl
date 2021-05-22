function init_constraint_struct(com, set::ComplementSet{F,S}, internals) where {F,S}
    inner_set = set.set
    fct = internals.fct
    if !(internals.fct isa SAF) && F <: SAF
        fct = get_saf(internals.fct)
    end

    constraint = get_constraint(com, fct, inner_set)
    return get_complement_constraint(com, constraint)
end
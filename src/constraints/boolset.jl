function init_constraint_struct(set::BoolSet{F1,F2}, internals) where {F1,F2}
    f = MOIU.eachscalar(internals.fct)

    lhs_fct = f[1:set.lhs_dimension]
    rhs_fct = f[end-set.rhs_dimension+1:end]

    if F1 <: MOI.ScalarAffineFunction
        lhs_fct = get_saf(lhs_fct)
    end
    if F2 <: MOI.ScalarAffineFunction
        rhs_fct = get_saf(rhs_fct)
    end

    if F1 <: MOI.VectorOfVariables
        lhs_fct = get_vov(lhs_fct)
    end
    if F2 <: MOI.VectorOfVariables
        rhs_fct = get_vov(rhs_fct)
    end

   
    lhs = get_constraint(lhs_fct, set.lhs_set)
    rhs = get_constraint(rhs_fct, set.rhs_set)

    return bool_constraint(set, internals, lhs, rhs)
end

function bool_constraint(::AndSet, internals, lhs, rhs)
    AndConstraint(
        internals,
        lhs,
        rhs
    )
end

function bool_constraint(::OrSet, internals, lhs, rhs)
    OrConstraint(
        internals,
        lhs,
        rhs
    )
end


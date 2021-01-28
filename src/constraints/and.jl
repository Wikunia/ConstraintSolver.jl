function get_constraint(fct, set)
    if fct isa SAF
        return new_linear_constraint(fct, set)
    else
        internals = create_interals(fct, set)
        return init_constraint_struct(set, internals) 
    end
end

function init_constraint_struct(set::AndSet, internals)
    lhs = get_constraint(set.func1, set.set1)
    rhs = get_constraint(set.func2, set.set2)

    AndConstraint(
        internals,
        lhs,
        rhs
    )
end
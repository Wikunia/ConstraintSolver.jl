function constraint_hash(constraint::Union{AllDifferentConstraint, BasicConstraint})
    return hash([typeof(constraint.set), constraint.indices])
end

function constraint_hash(constraint::LinearConstraint)
    coeffs = [t.coefficient for t in constraint.fct.terms]
    if isa(constraint.set, MOI.EqualTo)
        rhs = constraint.set.value-constraint.fct.constant
    end
    if isa(constraint.set, MOI.LessThan)
        rhs = constraint.set.upper-constraint.fct.constant
    end
    return hash([typeof(constraint.set), constraint.indices, coeffs, rhs])
end

function constraint_hash(constraint::SingleVariableConstraint)
    # TODO: Needs to change if we have coefficients but then we probably support all `<=` constraints anyway
    return hash([typeof(constraint.set), constraint.indices])
end

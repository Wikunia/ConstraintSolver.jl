function constraint_hash(constraint::BasicConstraint)
    return hash([typeof(constraint.set), constraint.indices])
end

function constraint_hash(constraint::LinearConstraint)
    coeffs = [t.coefficient for t in constraint.fct.terms]
    if isa(constraint.set, MOI.EqualTo)
        rhs = constraint.set.value-constraint.fct.constant
    end
    return hash([typeof(constraint.set), constraint.indices, coeffs, rhs])
end

function constraint_hash(constraint::SingleVariableConstraint)
    return hash([nameof(constraint.fct), constraint.rhs, constraint.lhs])
end

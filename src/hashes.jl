function constraint_hash(constraint::BasicConstraint)
    return hash([constraint.fct, constraint.indices])
end

function constraint_hash(constraint::LinearConstraint)
    return hash([constraint.fct, constraint.indices, constraint.coeffs, constraint.operator, constraint.rhs])
end

function constraint_hash(constraint::SingleVariableConstraint)
    return hash([constraint.fct, constraint.rhs, constraint.lhs])
end
function constraint_hash(constraint::Union{BasicConstraint, LinearConstraint})
    return hash([constraint.fct, constraint.set])
end

function constraint_hash(constraint::SingleVariableConstraint)
    return hash([nameof(constraint.fct), constraint.rhs, constraint.lhs])
end

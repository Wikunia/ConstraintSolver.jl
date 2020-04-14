function constraint_hash(constraint::Union{AllDifferentConstraint,BasicConstraint})
    return hash([string(typeof(constraint.std.set)), constraint.std.indices])
end

function constraint_hash(constraint::LinearConstraint)
    coeffs = [t.coefficient for t in constraint.std.fct.terms]
    if isa(constraint.std.set, MOI.EqualTo)
        rhs = constraint.std.set.value - constraint.std.fct.constant
    end
    if isa(constraint.std.set, MOI.LessThan)
        rhs = constraint.std.set.upper - constraint.std.fct.constant
    end
    return hash([string(typeof(constraint.std.set)), constraint.std.indices, coeffs, rhs])
end

function constraint_hash(constraint::SingleVariableConstraint)
    return hash([string(typeof(constraint.std.set)), constraint.std.indices])
end

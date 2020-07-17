function constraint_hash(constraint::Union{AllDifferentConstraint, BasicConstraint, EqualConstraint})
    return hash([string(typeof(constraint.set)), constraint.indices])
end

function constraint_hash(constraint::TableConstraint)
    return hash([string(typeof(constraint.set)), constraint.indices, constraint.set.table])
end

function constraint_hash(constraint::LinearConstraint)
    coeffs = [t.coefficient for t in constraint.fct.terms]
    if isa(constraint.set, Union{MOI.EqualTo, CS.NotEqualTo})
        rhs = constraint.set.value - constraint.fct.constant
    end
    if isa(constraint.set, MOI.LessThan)
        rhs = constraint.set.upper - constraint.fct.constant
    end
    return hash([string(typeof(constraint.set)), constraint.indices, coeffs, rhs])
end

function constraint_hash(constraint::SingleVariableConstraint)
    return hash([string(typeof(constraint.set)), constraint.indices])
end

function constraint_hash(constraint::Union{IndicatorConstraint, ReifiedConstraint})
    return hash([string(typeof(constraint.set)), constraint.indices, constraint.activate_on, constraint_hash(constraint.inner_constraint)])
end

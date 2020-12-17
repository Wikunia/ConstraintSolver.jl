struct GreaterThan2LessThan <: MOI.Bridges.Constraint.AbstractBridge

end

function MOI.supports_constraint(::Type{GreaterThan2LessThan},
                ::Type{JuMP.GenericAffExpr}, ::Type{GreaterThan})
    return true
end

function JuMP.build_constraint(_error::Function, func::JuMP.GenericAffExpr,
    set::GreaterThan)
    constraint = JuMP.ScalarConstraint(func, set)
    return JuMP.BridgeableConstraint(constraint, GreaterThan2LessThan)
end

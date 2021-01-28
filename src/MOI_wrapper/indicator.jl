"""
    Support for indicator constraints with a set constraint as the right hand side
"""
function JuMP._build_indicator_constraint(
    _error::Function,
    variable::JuMP.AbstractVariableRef,
    jump_constraint::JuMP.VectorConstraint,
    ::Type{MOI.IndicatorSet{A}},
) where {A}
    S = typeof(jump_constraint.set)
    set = CS.IndicatorSet{A,S}(jump_constraint.set, 1 + length(jump_constraint.func))
    if jump_constraint.func isa Vector{VariableRef}
        vov = JuMP.VariableRef[variable]
    else
        vov = JuMP.AffExpr[variable]
    end
    append!(vov, jump_constraint.func)
    return JuMP.VectorConstraint(vov, set)
end
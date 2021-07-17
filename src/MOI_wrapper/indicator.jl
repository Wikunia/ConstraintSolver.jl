"""
    Support for indicator constraints with a set constraint as the right hand side
"""
function JuMP._build_indicator_constraint(
    _error::Function,
    variable::JuMP.AbstractVariableRef,
    constraint::JuMP.VectorConstraint,
    ::Type{MOI.IndicatorSet{A}},
) where {A}
    S = typeof(constraint.set)
    F = typeof(JuMP.moi_function(constraint))
    set = CS.IndicatorSet{A,F,S}(constraint.set, 1 + length(constraint.func))
    if constraint.func isa Vector{VariableRef}
        vov = JuMP.VariableRef[variable]
    else
        vov = JuMP.AffExpr[variable]
    end
    append!(vov, constraint.func)
    return JuMP.VectorConstraint(vov, set)
end
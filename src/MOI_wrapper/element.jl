"""
    Support for nice element 1D const constraint
"""
function Base.getindex(v::Vector{Int}, i::VariableRef)
    m = JuMP.owner_model(i)
    min_val, max_val = extrema(v)
    x = @variable(m, integer=true, lower_bound = min_val, upper_bound = max_val)
    @constraint(m, [x, i] in CS.Element1DConst(v))
    return x
end
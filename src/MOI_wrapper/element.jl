"""
    Support for nice element 1D const constraint
"""
function Base.getindex(v::AbstractVector{<:Integer}, i::VariableRef)
    m = JuMP.owner_model(i)
    # check if the AbstractVector has standard indexing
    if !checkbounds(Bool, v, 1:length(v))
        throw(ArgumentError("Currently the specified vector needs to be using standard indexing 1:... so OffsetArrays are not possible."))
    end
    v = collect(v)
    min_val, max_val = extrema(v)
    x = @variable(m, integer=true, lower_bound = min_val, upper_bound = max_val)
    @constraint(m, [x, i] in CS.Element1DConst(v))
    return x
end
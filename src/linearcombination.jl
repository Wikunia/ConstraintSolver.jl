function Base.:+(x::Variable, y::Variable)
    return LinearVariables([x.idx,y.idx],[1,1])
end

function Base.:+(x::LinearVariables, y::LinearVariables)
    return LinearVariables(vcat(x.indices, y.indices), vcat(x.coeffs, y.coeffs))
end

function Base.:*(x::Int, y::Variable)
    return LinearVariables([y.idx],[x])
end

function Base.:+(x::LinearVariables, y::Variable)
    lv = LinearVariables(x.indices, x.coeffs)
    push!(lv.indices, y.idx)
    push!(lv.coeffs, 1)
    return lv
end


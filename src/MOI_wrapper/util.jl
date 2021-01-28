"""
    new_linear_constraint(model::Optimizer, func::SAF{T}, set) where {T<:Real}

Create a new linear constraint and return a `LinearConstraint` with already a correct index
such that it can be simply added with [`add_constraint!`](@ref)
"""
function new_linear_constraint(model::Optimizer, func::SAF{T}, set) where {T<:Real}
    func = remove_zero_coeff(func)

    indices = [v.variable_index.value for v in func.terms]

    lc_idx = length(model.inner.constraints) + 1
    lc = LinearConstraint(lc_idx, func, set, indices)
    return lc
end

function remove_zero_coeff(func::MOI.ScalarAffineFunction)
    terms = [term for term in func.terms if term.coefficient != 0]
    return MOI.ScalarAffineFunction(terms, func.constant)
end

"""
    get_indices(func::VAF{T}) where {T}

Get indices from the VectorAffineFunction
"""
function get_indices(func::VAF{T}) where {T}
    return [v.scalar_term.variable_index.value for v in func.terms]
end

function get_vec_AbstractJuMPScalar(func::Vector{JuMP.VariableRef})
    return [v.index.value for v in func]
end

function get_vec_AbstractJuMPScalar(func::JuMP.AffExpr)
    return [v[1].index.value for v in func.terms]
end
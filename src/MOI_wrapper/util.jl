"""
    new_linear_constraint(model::Optimizer, func::SAF{T}, set) where {T<:Real}

Create a new linear constraint and return a `LinearConstraint` with already a correct index
such that it can be simply added with [`add_constraint!`](@ref)
"""
function new_linear_constraint(model::Optimizer, func::SAF{T}, set) where {T<:Real}
    lc = new_linear_constraint(func, set)
    lc.idx = length(model.inner.constraints) + 1
    return lc
end

function new_linear_constraint(func::SAF{T}, set) where {T<:Real}
    func = remove_zero_coeff(func)

    indices = [v.variable_index.value for v in func.terms]

    return LinearConstraint(0, func, set, indices)
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

"""
    get_inner_constraint

Create the inner constraint of a reified or indicator constraint
"""
function get_inner_constraint(func::VAF{T}, set::Union{ReifiedSet, IndicatorSet}, inner_set::MOI.AbstractVectorSet) where {T<:Real}
    f = MOIU.eachscalar(func)
    inner_internals = ConstraintInternals(
        0,
        f[2:end],
        set.set,
        get_indices(f[2:end]),
    )
    return init_constraint_struct(set.set, inner_internals)
end

function get_inner_constraint(func::VAF{T}, set::Union{ReifiedSet, IndicatorSet, MOI.IndicatorSet}, inner_set::MOI.AbstractScalarSet) where {T<:Real}
    inner_terms = [v.scalar_term for v in func.terms if v.output_index == 2]
    inner_constant = func.constants[2]
    inner_set = set.set

    inner_func = MOI.ScalarAffineFunction{T}(inner_terms, inner_constant)

    return new_linear_constraint(inner_func, inner_set)
end

function get_inner_constraint(vars::MOI.VectorOfVariables, set::Union{ReifiedSet, IndicatorSet}, inner_set)
    inner_internals = ConstraintInternals(
        0,
        MOI.VectorOfVariables(vars.variables[2:end]),
        set.set,
        Int[v.value for v in vars.variables[2:end]],
    )
    return init_constraint_struct(set.set, inner_internals)
end

"""
    concat_2_VAF(vaf1::MOI.VectorAffineFunction{T}, vaf2::MOI.VectorAffineFunction{T}) where {T}

Return a VectorAffineFunction which combines the two given. It shifts the output_index to make them compatible
"""
function concat_2_VAF(vaf1::MOI.VectorAffineFunction{T}, vaf2::MOI.VectorAffineFunction{T}) where {T}
    # update the output indices of the rhs_fct
    vaf2_terms = Vector{MOI.VectorAffineTerm{T}}()
    vaf1_dim = maximum(t->t.output_index, vaf1.terms)
    for term in vaf2.terms
        push!(vaf2_terms, MOI.VectorAffineTerm{T}(term.output_index + vaf1_dim, term.scalar_term))
    end
    vaf2 = MOI.VectorAffineFunction(vaf2_terms, vaf2.constants)
    return MOI.VectorAffineFunction([vaf1.terms..., vaf2.terms...],  [vaf1.constants..., vaf2.constants...])
end
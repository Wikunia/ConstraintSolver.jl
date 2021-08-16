"""
    new_linear_constraint(com::CS.CoM, func::SAF{T}, set) where {T<:Real}

Create a new linear constraint and return a `LinearConstraint` with already a correct index
such that it can be simply added with [`add_constraint!`](@ref)
"""
function new_linear_constraint(com::CS.CoM, func::SAF{T}, set) where {T<:Real}
    lc = get_linear_constraint(func, set)
    lc.idx = length(com.constraints) + 1
    return lc
end

function get_linear_constraint(func::SAF{T}, set) where {T<:Real}
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
function get_inner_constraint(com, func::VAF{T}, set::Union{ReifiedSet, IndicatorSet}, inner_set::MOI.AbstractVectorSet) where {T<:Real}
    f = MOIU.eachscalar(func)
    inner_internals = ConstraintInternals(
        0,
        f[2:end],
        set.set,
        get_indices(f[2:end]),
    )
    return init_constraint_struct(com, set.set, inner_internals)
end

"""
    get_inner_constraint(com, func::VAF{T}, set::Union{ReifiedSet, IndicatorSet}, inner_set::Union{ReifiedSet{A}, IndicatorSet{A}, MOI.IndicatorSet{A}}) where {A,T<:Real}

Create the inner constraint when the inner constraint is a reified or indicator constraint as well.
"""
function get_inner_constraint(com, func::VAF{T}, set::Union{ReifiedSet, IndicatorSet}, inner_set::Union{ReifiedSet{A}, IndicatorSet{A}, MOI.IndicatorSet{A}}) where {A,T<:Real}
    f = MOIU.eachscalar(func)
    inner_internals = ConstraintInternals(
        0,
        f[2:end],
        set.set,
        get_indices(f[2:end]),
    )

    inner_constraint = get_inner_constraint(com, f[2:end], inner_set, inner_set.set)
    complement_inner = get_complement_constraint(com, inner_constraint)
    indices = inner_internals.indices
    activator_internals = get_activator_internals(A, indices)
    if inner_set isa ReifiedSet
        constraint =
            ReifiedConstraint(inner_internals, activator_internals, inner_constraint, complement_inner)
    else
        constraint =
            IndicatorConstraint(inner_internals, activator_internals, inner_constraint)
    end
    return constraint
end

function get_inner_constraint(com, func::VAF{T}, set::Union{ReifiedSet, IndicatorSet, MOI.IndicatorSet}, inner_set::MOI.AbstractScalarSet) where {T<:Real}
    inner_terms = [v.scalar_term for v in func.terms if v.output_index == 2]
    inner_constant = func.constants[2]
    inner_set = set.set

    inner_func = MOI.ScalarAffineFunction{T}(inner_terms, inner_constant)

    return get_linear_constraint(inner_func, inner_set)
end

function get_inner_constraint(com, vars::MOI.VectorOfVariables, set::Union{ReifiedSet, IndicatorSet}, inner_set)
    inner_internals = ConstraintInternals(
        0,
        MOI.VectorOfVariables(vars.variables[2:end]),
        set.set,
        Int[v.value for v in vars.variables[2:end]],
    )
    return init_constraint_struct(com, set.set, inner_internals)
end

function get_activator_internals(A, indices)
    ActivatorConstraintInternals(A, indices[1] in indices[2:end], false, 0, false)
end

"""
    saf_is_svf(saf::MOI.ScalarAffineFunction)

Checks if a `ScalarAffineFunction` can be represented as a `SingleVariable`.
This can be used for example when having a `VectorAffineFunction` in `AllDifferentSet` constraint when the decision 
has to be made whether a new constraint + variable has to be created.
"""
function is_svf(saf::MOI.ScalarAffineFunction)
    !iszero(saf.constant) && return false
    length(saf.terms) != 1 && return false
    !isone(saf.terms[1].coefficient) && return false
    return true
end

function get_extrema(model::Optimizer, saf::MOI.ScalarAffineFunction{T}) where T
    min_val = saf.constant
    max_val = saf.constant
    for term in saf.terms 
        if term.coefficient < 0
            min_val += term.coefficient*model.variable_info[term.variable_index.value].upper_bound
            max_val += term.coefficient*model.variable_info[term.variable_index.value].lower_bound
        else
            min_val += term.coefficient*model.variable_info[term.variable_index.value].lower_bound
            max_val += term.coefficient*model.variable_info[term.variable_index.value].upper_bound
        end
    end
    return min_val, max_val
end

function is_discrete_saf(saf::MOI.ScalarAffineFunction{T}) where T 
    !isapprox(saf.constant, round(saf.constant)) && return false, saf.constant
    for term in saf.terms 
        !isapprox(term.coefficient, round(term.coefficient)) && return false, term.coefficient
    end
    return true, 0
end
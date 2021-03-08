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
    move_element_constraint(model)

If there are element constraints which are only used inside of an indicator or reified constraint
=> combine them with `&&` and deactivate the previously added element constraint
    this is to avoid filtering based on this element constraint when the inner constraint isn't active
"""
function move_element_constraint(model)
    com = model.inner
    T = parametric_type(com)
    constraints = com.constraints
    subscriptions = com.subscription
    for element_cons in constraints
        element_cons isa Element1DConstConstraint || continue
        element_var = element_cons.indices[1]

        # check if the element var only appears in indicator or reified constraints
        # Todo check if in or constraint
        only_inside = true
        for constraint in constraints[subscriptions[element_var]]
            # if not inside indicator or reified and not the current constraint that we check
            if !(constraint isa ActivatorConstraint) && !(constraint isa ReifiedConstraint) && constraint.idx != element_cons.idx
                only_inside = false
            end
        end
        !only_inside && continue
        # check if at least once inside
        only_inside = false
        for constraint in constraints[subscriptions[element_var]]
            if (constraint isa ActivatorConstraint)
                only_inside = true
                break
            end
        end
        !only_inside && continue

        element_cons.is_deactivated = true
        # Todo: Move into `AndConstraint`
        @show getproperty.(constraints[subscriptions[element_var]], :idx)
        for constraint in constraints[subscriptions[element_var]]
            constraint isa Element1DConstConstraint && continue
            AC = typeof(constraint)
            ACS = typeof_without_params(constraint.set)
            if ACS == MOI.IndicatorSet
                ACS = IndicatorSet
            end
            @show ACS
            constraint.is_deactivated = true
            if constraint.inner_constraint isa OrConstraint
                error("Not yet implemented")
            else
                fct = MOIU.operate(vcat, T, constraint.fct, element_cons.fct)
                set = AndSet{typeof(constraint.inner_constraint.fct), typeof(element_cons.fct)}(constraint.inner_constraint.set, element_cons.set)
                MOI.add_constraint(model, fct, ACS{MOI.ACTIVATE_ON_ONE}(set))
            end
            println("Added new constraint")
        end
    end
end

function get_activator_internals(A, indices)
    ActivatorConstraintInternals(A, indices[1] in indices[2:end], false, 0)
end
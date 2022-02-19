"""
    new_linear_constraint(com::CS.CoM, fct::SAF{T}, set) where {T<:Real}

Create a new linear constraint and return a `LinearConstraint` with already a correct index
such that it can be simply added with [`add_constraint!`](@ref)
"""
function new_linear_constraint(com::CS.CoM, fct::SAF{T}, set) where {T<:Real}
    lc = get_linear_constraint(fct, set)
    lc.idx = length(com.constraints) + 1
    return lc
end

function get_linear_constraint(fct::SAF{T}, set) where {T<:Real}
    fct, set = fct_constant_to_set(fct, set)
    fct = remove_zero_coeff(fct)

    indices = [v.variable.value for v in fct.terms]

    return LinearConstraint(0, fct, set, indices)
end

function remove_zero_coeff(fct::MOI.ScalarAffineFunction)
    terms = [term for term in fct.terms if term.coefficient != 0]
    return MOI.ScalarAffineFunction(terms, fct.constant)
end


function fct_constant_to_set(fct::SAF{T}, set::ConstraintProgrammingExtensions.Strictly) where T
    fct, inner_set = fct_constant_to_set(fct, set.set)
    return fct, ConstraintProgrammingExtensions.Strictly(inner_set)
end

function fct_constant_to_set(fct::SAF{T}, set::MathOptInterface.AbstractScalarSet) where T
    constant = fct.constant
    set = typeof(set)(set_value(set) - constant)
    fct = MOI.ScalarAffineFunction(fct.terms, zero(T))
    return fct, set
end

set_value(set::MOI.LessThan) = set.upper
set_value(set::MOI.GreaterThan) = set.lower
set_value(set::MOI.EqualTo) = set.value
set_value(set::ConstraintProgrammingExtensions.DifferentFrom) = set.value

"""
    get_indices(fct::VAF{T}) where {T}

Get indices from the VectorAffineFunction
"""
function get_indices(fct::VAF{T}) where {T}
    return [v.scalar_term.variable.value for v in fct.terms]
end

"""
    get_inner_constraint

Create the inner constraint of a reified or indicator constraint
"""
function get_inner_constraint(com, func::VAF{T}, set::Union{Reified, Indicator}, inner_set::MOI.AbstractVectorSet) where {T<:Real}
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
    get_inner_constraint(com, func::VAF{T}, set::Union{Reified, Indicator}, inner_set::Union{Reified{A}, Indicator{A}, MOI.Indicator{A}}) where {A,T<:Real}

Create the inner constraint when the inner constraint is a reified or indicator constraint as well.
"""
function get_inner_constraint(com, func::VAF{T}, set::Union{Reified, Indicator}, inner_set::Union{Reified{A}, Indicator{A}, MOI.Indicator{A}}) where {A,T<:Real}
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
    if inner_set isa Reified
        constraint =
            ReifiedConstraint(inner_internals, activator_internals, inner_constraint, complement_inner)
    else
        constraint =
            IndicatorConstraint(inner_internals, activator_internals, inner_constraint)
    end
    return constraint
end

function get_inner_constraint(com, func::VAF{T}, set::Union{Reified, Indicator, MOI.Indicator}, inner_set::MOI.AbstractScalarSet) where {T<:Real}
    inner_terms = [v.scalar_term for v in func.terms if v.output_index == 2]
    inner_constant = func.constants[2]
    inner_set = set.set

    inner_func = MOI.ScalarAffineFunction{T}(inner_terms, inner_constant)

    return get_linear_constraint(inner_func, inner_set)
end

function get_inner_constraint(com, vars::MOI.VectorOfVariables, set::Union{Reified, Indicator}, inner_set)
    inner_internals = ConstraintInternals(
        0,
        MOI.VectorOfVariables(vars.variables[2:end]),
        set.set,
        Int[v.value for v in vars.variables[2:end]],
    )
    return init_constraint_struct(com, set.set, inner_internals)
end

"""
    get_bool_constraint_fct_set(T, constraint::BoolConstraint, lhs_fct, lhs_set, rhs_fct, rhs_set)

Create the fct and set of a [`BoolConstraint`](@ref) which combines the left hand side with the right hand side.
"""
function get_bool_constraint_fct_set(T, constraint::BoolConstraint, lhs_fct, lhs_set, rhs_fct, rhs_set)
    BS = typeof_without_params(constraint.set)
    fct = MOIU.operate(vcat, T, lhs_fct, rhs_fct)
    set = BS{typeof(lhs_fct), typeof(rhs_fct)}(lhs_set, rhs_set)
    return fct, set
end

function find_element_var_and_combine(T, constraint::BoolConstraint, element_constraint, element_var)
    lhs = constraint.lhs
    rhs = constraint.rhs
    if element_var in lhs.indices
        if lhs isa BoolConstraint
            fct, set = find_element_var_and_combine(T, lhs, element_constraint, element_var)
        else
            fct = MOIU.operate(vcat, T, lhs.fct, element_constraint.fct)
            set = XNorSet{typeof(lhs.fct), typeof(element_constraint.fct)}(lhs.set, element_constraint.set)
        end
        fct, set = get_bool_constraint_fct_set(T, constraint, fct, set, rhs.fct, rhs.set)
    else
        if rhs isa BoolConstraint
            fct, set = find_element_var_and_combine(T, rhs, element_constraint, element_var)
        else
            fct = MOIU.operate(vcat, T, element_constraint.fct, rhs.fct)
            set = XNorSet{typeof(element_constraint.fct), typeof(rhs.fct)}(element_constraint.set, rhs.set)
        end
        fct, set = get_bool_constraint_fct_set(T, constraint, lhs.fct, lhs.set, fct, set)
    end
    return fct, set
end

function create_new_activator_constraint(model, activation_constraint::ActivatorConstraint, fct, set)
    com = model.inner
    T = parametric_type(com)
    ACS = typeof_without_params(activation_constraint.set)
    A = get_activation_condition(activation_constraint.set)
    if ACS == MOI.Indicator
        ACS = Indicator
    end
    f = MOIU.eachscalar(activation_constraint.fct)

    activator_fct = f[1]
    fct = MOIU.operate(vcat, T, activator_fct, fct)
    MOI.add_constraint(model, fct, ACS{A,typeof(fct)}(set))
end

"""
    move_element_constraint(model)

If there are element constraints which are only used inside of an indicator or reified constraint
=> combine them with xnor and deactivate the previously added element constraint
    this is to avoid filtering based on this element constraint when the inner constraint isn't active
For more see: https://github.com/Wikunia/ConstraintSolver.jl/pull/213#issuecomment-860954185
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
        only_inside = true
        for constraint in constraints[subscriptions[element_var]]
            # if not inside indicator, reified or OrConstraint and not the current constraint that we check
            if !(constraint isa ActivatorConstraint) && !(constraint isa OrConstraint) && constraint.idx != element_cons.idx
                only_inside = false
            end
        end
        !only_inside && continue
        # check if at least once inside
        only_inside = false
        for constraint in constraints[subscriptions[element_var]]
            if constraint isa ActivatorConstraint || constraint isa OrConstraint
                only_inside = true
                break
            end
        end
        !only_inside && continue

        element_cons.is_deactivated = true
        for constraint in constraints[subscriptions[element_var]]
            constraint isa Element1DConstConstraint && continue
            constraint.is_deactivated && continue
            fct, set = nothing, nothing
            if constraint isa ActivatorConstraint
                if constraint.inner_constraint isa OrConstraint
                    inner_constraint = constraint.inner_constraint
                    fct, set = find_element_var_and_combine(T, inner_constraint, element_cons, element_var)
                else
                    fct = MOIU.operate(vcat, T, constraint.inner_constraint.fct, element_cons.fct)
                    set = XNorSet{typeof(constraint.inner_constraint.fct), typeof(element_cons.fct)}(constraint.inner_constraint.set, element_cons.set)
                end
                create_new_activator_constraint(model, constraint, fct, set)
            else # OrConstraint
                fct, set = find_element_var_and_combine(T, constraint, element_cons, element_var)
                MOI.add_constraint(model, fct, set)
            end
        end
    end
end

function get_activator_internals(A, indices)
    ActivatorConstraintInternals(A, indices[1] in indices[2:end], false, 0)
end

"""
    is_vi(saf::MOI.ScalarAffineFunction)

Checks if a `ScalarAffineFunction` can be represented as a `VariableIndex`.
This can be used for example when having a `VectorAffineFunction` in `AllDifferentSet` constraint when the decision 
has to be made whether a new constraint + variable has to be created.
"""
function is_vi(saf::MOI.ScalarAffineFunction)
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
            min_val += term.coefficient*model.variable_info[term.variable.value].upper_bound
            max_val += term.coefficient*model.variable_info[term.variable.value].lower_bound
        else
            min_val += term.coefficient*model.variable_info[term.variable.value].lower_bound
            max_val += term.coefficient*model.variable_info[term.variable.value].upper_bound
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
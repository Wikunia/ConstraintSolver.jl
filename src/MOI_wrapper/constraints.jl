"""
JuMP constraints
"""
sense_to_set(::Function, ::Val{:!=}) = NotEqualTo(0.0)
sense_to_set(::Function, ::Val{:<}) = Strictly(MOI.LessThan(0.0))
sense_to_set(::Function, ::Val{:>}) = Strictly(MOI.GreaterThan(0.0))

MOIU.shift_constant(set::NotEqualTo, value) = NotEqualTo(set.value + value)

include("indicator.jl")
include("reified.jl")
include("bool.jl")
include("anti.jl")

"""
MOI constraints
"""

"""
Linear constraints
"""
MOI.supports_constraint(
    ::Optimizer,
    ::Type{SAF{T}},
    ::Type{MOI.EqualTo{T}},
) where {T<:Real} = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{SAF{T}},
    ::Type{MOI.LessThan{T}},
) where {T<:Real} = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{EqualSetInternal},
) = true
MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{AllDifferentSetInternal},
) = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{TableSetInternal},
) = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{SAF{T}},
    ::Type{NotEqualTo{T}},
) where {T<:Real} = true

# Don't directly support StrictlyGreaterThan => use a bridge
MOI.supports_constraint(
    ::Optimizer,
    ::Type{SAF{T}},
    ::Type{Strictly{T, MOI.LessThan{T}}},
) where {T<:Real} = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{<:MathOptInterface.AbstractFunction},
    ::Type{<:AntiSet},
) = true

function MOI.supports_constraint(
    ::Optimizer,
    func::Type{VAF{T}},
    set::Type{OS},
) where {A,T<:Real,IS<:MOI.AbstractScalarSet,OS<:MOI.IndicatorSet{A,IS}}
    if IS <: MOI.GreaterThan || IS <: Strictly{T, MOI.GreaterThan{T}}
        return false
    end
    return A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    func::Type{VAF{T}},
    set::Type{OS},
) where {A,T<:Real,IS,OS<:CS.IndicatorSet{A,IS}}
    if IS <: AbstractBoolSet
        return is_boolset_supported(optimizer, IS)
    end
    return A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    func::Type{MOI.VectorOfVariables},
    set::Type{OS},
) where {A,IS,OS<:CS.IndicatorSet{A,IS}}
    !(A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO) && return false
    return MOI.supports_constraint(optimizer, func, IS)
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    func::Type{MOI.VectorOfVariables},
    set::Type{OS}
) where {A,IS,OS<:CS.ReifiedSet{A,IS}}
    !(A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO) && return false
    return MOI.supports_constraint(optimizer, func, IS)
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    func::Type{VAF{T}},
    set::Type{OS},
) where {A,T<:Real,IS,OS<:CS.ReifiedSet{A,IS}}
    if IS <: MOI.GreaterThan || IS <: Strictly{T, MOI.GreaterThan{T}}
        return false
    end
    if IS <: AbstractBoolSet
        return is_boolset_supported(optimizer, IS)
    end
    return A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    func::Type{VAF{T}},
    set::Type{BS},
) where {T,F1,F2,F1dim,F2dim,S1,S2,BS<:CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}}
    return is_boolset_supported(optimizer, set)
end


MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{GeqSetInternal},
) = true

"""
    Return whether the two constraint inside the `AbstractBoolSet` are supported directly by the solver
"""
function is_boolset_supported(optimizer::Optimizer, ::Type{<:CS.AbstractBoolSet{F1,F2,F1dim,F2dim,S1,S2}}) where {F1, F2, F1dim, F2dim, S1, S2}
    is_supported = MOI.supports_constraint(optimizer, F1, S1) && MOI.supports_constraint(optimizer, F2, S2)
    return is_supported
end

function check_inbounds(model::Optimizer, aff::SAF{T}) where {T<:Real}
    for term in aff.terms
        check_inbounds(model, term.variable_index)
    end
    return
end

function check_inbounds(model::Optimizer, vov::MOI.VectorOfVariables)
    for var in vov.variables
        check_inbounds(model, var)
    end
    return
end

"""
    add_constraint!(model::Optimizer, constraint::Constraint)

Calls `add_constraint!` on the `CoM` without setting pvals.
The variable bounds might not be ready at this stage.
"""
function add_constraint!(model::Optimizer, constraint::Constraint)
    add_constraint!(model.inner, constraint; set_pvals = false)
end

"""
    create_interals(com::CoM, vars, set)

Create ConstraintInternals for a vector of variables constraint
"""
function create_interals(com::CoM, vars, set)
    internals = create_interals(vars, set)
    internals.idx = length(com.constraints) + 1
    return internals
end

"""
    create_interals(vars::MOI.VectorOfVariables, set)

Create ConstraintInternals for a vector of variables constraint
"""
function create_interals(vars::MOI.VectorOfVariables, set)
    ConstraintInternals(
        0,
        vars,
        set,
        Int[v.value for v in vars.variables],
    )
end

"""
    create_interals(func::VAF{T}, set) where {T}

Create ConstraintInternals for a vector of variables constraint
"""
function create_interals(func::VAF{T}, set) where {T}
    ConstraintInternals(
        0,
        func,
        set,
        get_indices(func)
    )
end

"""
    get_complement_constraint(com, constraint)

Return the anti constraint if it exists and `nothing` otherwise.
The anti constraint is the constraint that expresses the opposite i.e
input: 2x + 7 <= 5 => 2x + 7 > 5
 - it will actually output only less than constraints not great than as it's not supported
input 5x == 2 => 5x != 2

Currently it's only implemented for linear constraints
"""
function get_complement_constraint(com, constraint::Constraint)
    return nothing
end

function get_complement_constraint(com, constraint::LinearConstraint{T}) where T
    set = constraint.set
    complement_fct = nothing
    complement_set = nothing
    if constraint.set isa MOI.LessThan
        complement_fct = MOIU.operate(-, T, constraint.fct)
        complement_set = Strictly(MOI.LessThan(-set.upper))
    elseif constraint.set isa Strictly{T, MOI.LessThan{T}}
        complement_fct = MOIU.operate(-, T, constraint.fct)
        complement_set = MOI.LessThan(-set.set.upper)
    elseif constraint.set isa MOI.EqualTo
        complement_fct = copy(constraint.fct)
        complement_set = NotEqualTo(set.value)
    elseif constraint.set isa NotEqualTo
        complement_fct = copy(constraint.fct)
        complement_set = MOI.EqualTo(set.value)
    end
    complement_lc = get_linear_constraint(complement_fct, complement_set)
    return complement_lc
end

function get_complement_constraint(com, constraint::BoolConstraint)
    lhs_complement_constraint = get_complement_constraint(com, constraint.lhs)
    rhs_complement_constraint = get_complement_constraint(com, constraint.rhs)

    if lhs_complement_constraint === nothing || rhs_complement_constraint === nothing
        return nothing
    end

    T = parametric_type(com)
    fct = MOIU.operate(vcat, T, lhs_complement_constraint.fct, rhs_complement_constraint.fct)
    return complement_bool_constraint(com, typeof(constraint.set), fct, lhs_complement_constraint, rhs_complement_constraint)
end

"""
    complement_bool_constraint(com, bst::Type{<:AbstractBoolSet}, fct, lhs_constraint::Constraint, rhs_constraint::Constraint)

Return the anti constraint with the already anti constraints `lhs_constraint` and `rhs_constraint`
"""
function complement_bool_constraint(com, bst::Type{<:AbstractBoolSet}, fct, lhs_constraint::Constraint, rhs_constraint::Constraint)
    set = complement_set(bst){typeof(lhs_constraint.fct), typeof(rhs_constraint.fct)}(lhs_constraint.set, rhs_constraint.set)

    internals = ConstraintInternals(0,fct,set,get_indices(fct))
    return complement_constraint_type(bst)(com, internals, lhs_constraint, rhs_constraint)
end

"""
    MOI.add_constraint(
        model::Optimizer,
        vars::MOI.VectorOfVariables,
        set::MOI.AbstractVectorSet,
    )

Add all kinds of vector of variables constraints like:
TableConstraint and AllDifferentConstraint
"""
function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::MOI.AbstractVectorSet,
)
    check_inbounds(model, vars)
    com = model.inner

    internals = create_interals(com, vars, set)

    constraint = init_constraint_struct(com, set, internals)

    add_constraint!(model, constraint)
    if set isa AllDifferentSetInternal
        com.info.n_constraint_types.alldifferent += 1
    elseif set isa TableSetInternal
        com.info.n_constraint_types.table += 1
    elseif set isa EqualSetInternal
        com.info.n_constraint_types.equality += 1
    end

    return MOI.ConstraintIndex{MOI.VectorOfVariables,typeof(set)}(length(com.constraints))
end

"""
    MOI.add_constraint(
        model::Optimizer,
        vars::MOI.AbstractFunction,
        set::AntiSet,
    )

Add an AntiConstraint
"""
function MOI.add_constraint(
    model::Optimizer,
    fct::MOI.AbstractFunction,
    set::AntiSet,
)
    com = model.inner
    inner_set = set.set
    constraint = get_constraint(com, fct, inner_set)
    complement_constraint = get_complement_constraint(com, constraint)
    complement_constraint.idx = length(com.constraints)+1

    add_constraint!(model, complement_constraint)
    return MOI.ConstraintIndex{typeof(fct),typeof(set)}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::SAF{T},
    set::MOI.EqualTo{T},
) where {T<:Real}
    check_inbounds(model, func)

    if length(func.terms) == 1
        vidx = func.terms[1].variable_index.value
        val = convert(Int, set.value / func.terms[1].coefficient)
        push!(model.inner.init_fixes, (vidx, val))
        return MOI.ConstraintIndex{SAF{T},MOI.EqualTo{T}}(0)
    elseif length(func.terms) == 2 && set.value == zero(T)
        if func.terms[1].coefficient == -func.terms[2].coefficient
            # we have the form a == b
            vecOfvar = MOI.VectorOfVariables([
                func.terms[1].variable_index,
                func.terms[2].variable_index,
            ])
            com = model.inner
            internals = ConstraintInternals(
                length(com.constraints) + 1,
                vecOfvar,
                CS.EqualSetInternal(2),
                Int[v.value for v in vecOfvar.variables],
            )
            constraint = EqualConstraint(internals, ones(Int, 2))

            add_constraint!(model, constraint)
            com.info.n_constraint_types.equality += 1
            return MOI.ConstraintIndex{SAF{T},MOI.EqualTo{T}}(length(model.inner.constraints))
        end
    end

    lc = new_linear_constraint(model.inner, func, set)

    add_constraint!(model, lc)
    model.inner.info.n_constraint_types.equality += 1

    return MOI.ConstraintIndex{SAF{T},MOI.EqualTo{T}}(length(model.inner.constraints))
end

function add_variable_less_than_variable_constraint(
    model::Optimizer,
    func::SAF{T},
    set::MOI.LessThan{T},
) where {T<:Real}
    reverse_order = false
    if func.terms[1].coefficient != 1.0 || func.terms[2].coefficient != -1.0
        if func.terms[1].coefficient == -1.0 && func.terms[2].coefficient == 1.0
            # rhs is lhs and other way around
            reverse_order = true
        end
    end

    com = model.inner

    if reverse_order
        lhs = func.terms[2].variable_index.value
        rhs = func.terms[1].variable_index.value
    else
        lhs = func.terms[1].variable_index.value
        rhs = func.terms[2].variable_index.value
    end

    internals = ConstraintInternals(
        length(model.inner.constraints) + 1, # constraint idx
        func,
        set,
        [lhs, rhs],
    )
    svc = SingleVariableConstraint(internals, lhs, rhs)

    add_constraint!(model, svc)
    com.info.n_constraint_types.inequality += 1

    return MOI.ConstraintIndex{SAF{T},typeof(set)}(length(model.inner.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::SAF{T},
    set::MOI.LessThan{T},
) where {T<:Real}
    check_inbounds(model, func)

    # support for a <= b which is written as a-b <= 0
    # currently only supports if the coefficients are 1 and -1
    if set.upper == 0.0 &&
       length(func.terms) == 2 &&
       abs(func.terms[1].coefficient) == 1.0 &&
       abs(func.terms[2].coefficient) == 1.0 &&
       func.terms[1].coefficient == -func.terms[2].coefficient
        return add_variable_less_than_variable_constraint(model, func, set)
    end

    lc = new_linear_constraint(model.inner, func, set)

    add_constraint!(model, lc)
    model.inner.info.n_constraint_types.inequality += 1

    return MOI.ConstraintIndex{SAF{T},typeof(set)}(length(model.inner.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::SAF{T},
    set::NotEqualTo{T},
) where {T<:Real}
    com = model.inner
    com.info.n_constraint_types.notequal += 1

    # support for cx != a where a and c are constants
    if length(func.terms) == 1
        # reformulate to x != a where x is variable and a a constant
        rhs = set.value / func.terms[1].coefficient
        if isapprox_discrete(com, rhs)
            rhs = get_approx_discrete(rhs)
            rm!(
                com,
                com.search_space[func.terms[1].variable_index.value],
                rhs;
                changes = false,
            )
        end
        return MOI.ConstraintIndex{SAF{T},NotEqualTo{T}}(0)
    end

    lc = new_linear_constraint(model.inner, func, set)

    add_constraint!(model, lc)

    return MOI.ConstraintIndex{SAF{T},NotEqualTo{T}}(length(com.constraints))
end
function MOI.add_constraint(
    model::Optimizer,
    func::SAF{T},
    set::Strictly{T, MOI.LessThan{T}},
) where {T<:Real}
    check_inbounds(model, func)

    lc = new_linear_constraint(model.inner, func, set)

    add_constraint!(model, lc)
    model.inner.info.n_constraint_types.inequality += 1

    return MOI.ConstraintIndex{SAF{T},typeof(set)}(length(model.inner.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::IS,
) where {A,T<:Real,ASS<:MOI.AbstractScalarSet,IS<:MOI.IndicatorSet{A,ASS}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    indices = get_indices(func)

    internals = ConstraintInternals(
        length(com.constraints)+1,
        func,
        MOI.IndicatorSet{A}(set.set),
        indices,
    )

    activator_internals = get_activator_internals(A, indices)

    lc = get_inner_constraint(com, func, set, set.set)

    constraint = IndicatorConstraint(internals, activator_internals, lc)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},MOI.IndicatorSet{A,ASS}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::IS,
) where {A,S,IS<:CS.IndicatorSet{A,S}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    internals = create_interals(com, vars, set)

    inner_constraint = get_inner_constraint(com, vars, set, set.set)

    indices = internals.indices
    activator_internals = get_activator_internals(A, indices)
    constraint =
        IndicatorConstraint(internals, activator_internals, inner_constraint)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{MOI.VectorOfVariables,CS.IndicatorSet{A,S}}(length(com.constraints))
end


function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::IS,
) where {T,A,S<:MOI.AbstractVectorSet,IS<:CS.IndicatorSet{A,S}}
    com = model.inner
    com.info.n_constraint_types.reified += 1

    internals = create_interals(com, func, set)

    inner_constraint = get_inner_constraint(com, func, set, set.set)
    indices = internals.indices

    activator_internals = get_activator_internals(A, indices)

    constraint =
        IndicatorConstraint(internals, activator_internals, inner_constraint)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},CS.IndicatorSet{A,S}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::RS,
) where {A,S<:MOI.AbstractScalarSet,T<:Real,RS<:ReifiedSet{A,S}}
    com = model.inner
    com.info.n_constraint_types.reified += 1

    indices = get_indices(func)

    internals = ConstraintInternals(
        length(com.constraints)+1,
        func,
        typeof(set)(set.set, set.dimension),
        indices,
    )

    # for normal linear constraints
    lc = get_inner_constraint(com, func, set, set.set)
    complement_lc = get_complement_constraint(model, lc)

    activator_internals = get_activator_internals(A, indices)
    constraint = ReifiedConstraint(internals, activator_internals, lc, complement_lc)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},CS.ReifiedSet{A,S}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::RS,
) where {A,S<:MOI.AbstractVectorSet,RS<:CS.ReifiedSet{A,S}}
    com = model.inner
    com.info.n_constraint_types.reified += 1
    internals = create_interals(com, vars, set)

    inner_constraint = get_inner_constraint(com, vars, set, set.set)
    complement_constraint = get_complement_constraint(model, inner_constraint)
    indices = internals.indices
    activator_internals = get_activator_internals(A, indices)
    constraint =
        ReifiedConstraint(internals, activator_internals, inner_constraint, complement_constraint)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{MOI.VectorOfVariables,CS.ReifiedSet{A,S}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::RS,
) where {T,A,S<:MOI.AbstractVectorSet,RS<:CS.ReifiedSet{A,S}}
    com = model.inner
    com.info.n_constraint_types.reified += 1

    internals = create_interals(com, func, set)

    inner_constraint = get_inner_constraint(com, func, set, set.set)
    complement_constraint = get_complement_constraint(com, inner_constraint)
    indices = internals.indices
    activator_internals = get_activator_internals(A, indices)
    constraint =
        ReifiedConstraint(internals, activator_internals, inner_constraint, complement_constraint)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},CS.ReifiedSet{A,S}}(length(com.constraints))
end


function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::BS,
) where {T,BS<:AbstractBoolSet}
    com = model.inner
    internals = create_interals(com, func, set)
    constraint = init_constraint_struct(com, set, internals)
    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},typeof(set)}(length(com.constraints))
end

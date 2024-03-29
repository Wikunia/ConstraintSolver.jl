"""
JuMP constraints
"""
operator_to_set(::Function, ::Val{:!=}) = CPE.DifferentFrom(0.0)
operator_to_set(::Function, ::Val{:<}) = CPE.Strictly(MOI.LessThan(0.0))
operator_to_set(::Function, ::Val{:>}) = CPE.Strictly(MOI.GreaterThan(0.0))

include("element.jl")
include("indicator.jl")
include("reified.jl")
include("bool.jl")
include("complement.jl")

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
    ::Type{CPE.AllEqual},
) = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{CPE.AllDifferent},
) = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{VAF{T}},
    ::Type{CPE.AllDifferent},
) where {T <: Real} = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{Element1DConstInner},
) = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{TableSetInternal},
) = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{VAF{T}},
    ::Type{TableSetInternal},
) where {T <: Real} = true

MOI.supports_constraint(
    ::Optimizer,
    ::Type{SAF{T}},
    ::Type{CPE.DifferentFrom{T}},
) where {T<:Real} = true

# Don't directly support StrictlyGreaterThan => use a bridge
MOI.supports_constraint(
    ::Optimizer,
    ::Type{SAF{T}},
    ::Type{CPE.Strictly{MOI.LessThan{T}, T}},
) where {T<:Real} = true

function MOI.supports_constraint(
    optimizer::Optimizer,
    fct::Type{<:MathOptInterface.AbstractFunction},
    ::Type{<:ComplementSet{F,S}},
) where {F,S} 
    return MOI.supports_constraint(optimizer, F, S)
end

function MOI.supports_constraint(
    ::Optimizer,
    func::Type{VAF{T}},
    set::Type{OS},
) where {A,T<:Real,IS<:MOI.AbstractScalarSet,OS<:MOI.Indicator{A,IS}}
    if IS <: MOI.GreaterThan || IS <: CPE.Strictly{MOI.GreaterThan{T}}
        return false
    end
    return A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO
end

supports_inner_constraint(optimizer::Optimizer, func, set) = MOI.supports_constraint(optimizer, func, set)
supports_inner_constraint(optimizer::Optimizer, func::Type{VAF{T}}, ::Type{CPE.AllDifferent}) where T = false
supports_inner_constraint(optimizer::Optimizer, func::Type{VAF{T}}, ::Type{TableSetInternal}) where T = false

function MOI.supports_constraint(
    optimizer::Optimizer,
    func::Type{<:MOI.AbstractFunction},
    set::Type{OS},
) where {A,F,IS,OS<:CS.Indicator{A,F,IS}}
    !(A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO) && return false
    return supports_inner_constraint(optimizer, F, IS)
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    func::Type{<:MOI.AbstractFunction},
    set::Type{OS}
) where {A,F,IS,OS<:CS.Reified{A,F,IS}}
    !(A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO) && return false
    return supports_inner_constraint(optimizer, F, IS)
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    func::Type{<:Union{VAF{T},MOI.VectorOfVariables}},
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
    is_supported_left = MOI.supports_constraint(optimizer, F1, S1)
    is_supported_right = MOI.supports_constraint(optimizer, F2, S2)
    return is_supported_left && is_supported_right
end

function check_inbounds(model::Optimizer, aff::SAF{T}) where {T<:Real}
    for term in aff.terms
        check_inbounds(model, term.variable)
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
    create_internals(com::CoM, vars, set)

Create ConstraintInternals for a vector of variables constraint
"""
function create_internals(com::CoM, vars, set)
    internals = create_internals(vars, set)
    internals.idx = length(com.constraints) + 1
    return internals
end

"""
    create_internals(vars::MOI.VectorOfVariables, set)

Create ConstraintInternals for a vector of variables constraint
"""
function create_internals(vars::MOI.VectorOfVariables, set)
    ConstraintInternals(
        0,
        vars,
        set,
        Int[v.value for v in vars.variables],
    )
end

"""
    create_internals(func::VAF{T}, set) where {T}

Create ConstraintInternals for a vector of variables constraint
"""
function create_internals(func::VAF{T}, set) where {T}
    ConstraintInternals(
        0,
        func,
        set,
        get_indices(func)
    )
end

"""
    get_complement_constraint(com, constraint)

Return the complement constraint if it exists and `nothing` otherwise.
The complement constraint is the constraint that expresses the opposite i.e
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
        complement_set = CPE.Strictly(MOI.LessThan(-set.upper))
    elseif constraint.set isa CPE.Strictly{MOI.LessThan{T}, T}
        complement_fct = MOIU.operate(-, T, constraint.fct)
        complement_set = MOI.LessThan(-set.set.upper)
    elseif constraint.set isa MOI.EqualTo
        complement_fct = copy(constraint.fct)
        complement_set = CPE.DifferentFrom(set.value)
    elseif constraint.set isa CPE.DifferentFrom
        complement_fct = copy(constraint.fct)
        complement_set = MOI.EqualTo(set.value)
    end
    complement_lc = get_linear_constraint(complement_fct, complement_set)
    return complement_lc
end

function get_complement_constraint(com, constraint::BoolConstraint)
    return complement_bool_constraint(com, typeof(constraint.set), constraint.fct, constraint.lhs, constraint.rhs)
end

"""
    complement_bool_constraint(com, bst::Type{<:AbstractBoolSet}, fct, lhs_constraint::Constraint, rhs_constraint::Constraint)

Return the complement constraint
"""
function complement_bool_constraint(com, bset::Type{<:AbstractBoolSet}, fct, lhs_constraint::Constraint, rhs_constraint::Constraint)
    cs = complement_set(bset)
    # if there is no complement set check for demorgan complement sets
    if cs === nothing 
        dcs = demorgan_complement_set(bset)
        if dcs === nothing 
            return nothing # if no complement set option exists
        end
        # demorgan rule -> complement the inners and then apply the demorgan set
        lhs_complement_constraint = get_complement_constraint(com, lhs_constraint)
        rhs_complement_constraint = get_complement_constraint(com, rhs_constraint)
        if lhs_complement_constraint === nothing || rhs_complement_constraint === nothing
            return nothing
        end
        T = parametric_type(com)
        fct = MOIU.operate(vcat, T, lhs_complement_constraint.fct, rhs_complement_constraint.fct)
        set = dcs{typeof(lhs_complement_constraint.fct), typeof(rhs_complement_constraint.fct)}(lhs_complement_constraint.set, rhs_complement_constraint.set)
        internals = ConstraintInternals(0,fct,set,get_indices(fct))
        return demorgan_complement_constraint_type(bset)(com, internals, lhs_complement_constraint, rhs_complement_constraint)
    else
        set = cs{typeof(lhs_constraint.fct), typeof(rhs_constraint.fct)}(lhs_constraint.set, rhs_constraint.set)
        internals = ConstraintInternals(0,fct,set,get_indices(fct))
        return complement_constraint_type(bset)(com, internals, lhs_constraint, rhs_constraint)
    end
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

    internals = create_internals(com, vars, set)

    constraint = init_constraint_struct(com, set, internals)

    add_constraint!(model, constraint)
    if set isa CPE.AllDifferent
        com.info.n_constraint_types.alldifferent += 1
    elseif set isa TableSetInternal
        com.info.n_constraint_types.table += 1
    elseif set isa CPE.AllEqual
        com.info.n_constraint_types.equality += 1
    elseif set isa Element1DConstInner
        com.info.n_constraint_types.element += 1
    end

    return MOI.ConstraintIndex{MOI.VectorOfVariables,typeof(set)}(length(com.constraints))
end

"""
    function MOI.add_constraint(
        model::Optimizer,
        vaf::VAF{T},
        set::Union{CPE.AllDifferent, TableSetInternal},
    ) where T

`VectorAffineFunction` constraint for `AllDifferentSet` or `TableSet` to support for things like 
`[a+1, b+2, c+3] in CS.AllDifferent()` or
`[a, b, 4] in TableSet(...)`
"""
function MOI.add_constraint(
    model::Optimizer,
    vaf::VAF{T},
    set::Union{CPE.AllDifferent, TableSetInternal},
) where T
    fs = MOIU.eachscalar(vaf)
    variables = Vector{MOI.VariableIndex}(undef, length(fs))
    for (i,f) in enumerate(fs)
        # we need to create a new variable and SAF constraint when it's not a variable index
        if !is_vi(f)
            discrete, non_continuous_value = is_discrete_saf(f)
            if !discrete
                throw(DomainError(non_continuous_value, "The constant and all coefficients need to be discrete"))
            end
            vidx = MOI.add_variable(model)
            variables[i] = vidx
            min_val, max_val = get_extrema(model, f)
            MOI.add_constraint(model, vidx, MOI.Integer())
            MOI.add_constraint(model, vidx, MOI.Interval(min_val, max_val))
            new_constraint_fct = MOIU.operate(-, T, f, vidx)
            MOI.add_constraint(model, new_constraint_fct, MOI.EqualTo(0.0))
        else
            variables[i] = f.terms[1].variable
        end
    end
    ci = MOI.add_constraint(model, MOI.VectorOfVariables(variables), set)
    return MOI.ConstraintIndex{VAF{T},typeof(set)}(ci.value) 
end

"""
    MOI.add_constraint(
        model::Optimizer,
        vars::MOI.AbstractFunction,
        set::ComplementSet,
    )

Add a complement constraint
"""
function MOI.add_constraint(
    model::Optimizer,
    fct::F,
    set::ComplementSet{CF},
) where {F<:MOI.AbstractFunction,CF}
    com = model.inner
    inner_set = set.set
    if CF <: SAF
        fct = get_saf(fct)
    end
    constraint = get_constraint(com, fct, inner_set)
    complement_constraint = get_complement_constraint(com, constraint)
    complement_constraint.idx = length(com.constraints)+1

    add_constraint!(model, complement_constraint)
    return MOI.ConstraintIndex{F,typeof(set)}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::SAF{T},
    set::MOI.EqualTo{T},
) where {T<:Real}
    check_inbounds(model, func)

    if length(func.terms) == 1
        vidx = func.terms[1].variable.value
        val = convert(Int, (set.value - func.constant) / func.terms[1].coefficient)
        push!(model.inner.init_fixes, (vidx, val))
        return MOI.ConstraintIndex{SAF{T},MOI.EqualTo{T}}(0)
    elseif length(func.terms) == 2 && set.value == zero(T) && func.constant == zero(T)
        if func.terms[1].coefficient == -func.terms[2].coefficient
            # we have the form a == b
            vecOfvar = MOI.VectorOfVariables([
                func.terms[1].variable,
                func.terms[2].variable,
            ])
            com = model.inner
            internals = ConstraintInternals(
                length(com.constraints) + 1,
                vecOfvar,
                CS.CPE.AllEqual(2),
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
        lhs = func.terms[2].variable.value
        rhs = func.terms[1].variable.value
    else
        lhs = func.terms[1].variable.value
        rhs = func.terms[2].variable.value
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
    fct::SAF{T},
    set::MOI.LessThan{T},
) where {T<:Real}
    check_inbounds(model, fct)
    fct, set = fct_constant_to_set(fct, set)

    # support for a <= b which is written as a-b <= 0
    # currently only supports if the coefficients are 1 and -1
    if set.upper == 0.0 &&
       length(fct.terms) == 2 &&
       abs(fct.terms[1].coefficient) == 1.0 &&
       abs(fct.terms[2].coefficient) == 1.0 &&
       fct.terms[1].coefficient == -fct.terms[2].coefficient
        return add_variable_less_than_variable_constraint(model, fct, set)
    end

    lc = new_linear_constraint(model.inner, fct, set)

    add_constraint!(model, lc)
    model.inner.info.n_constraint_types.inequality += 1

    return MOI.ConstraintIndex{SAF{T},typeof(set)}(length(model.inner.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    fct::SAF{T},
    set::CPE.DifferentFrom{T},
) where {T<:Real}
    com = model.inner
    com.info.n_constraint_types.notequal += 1
    fct, set = fct_constant_to_set(fct, set)

    # support for cx != a where a and c are constants
    if length(fct.terms) == 1
        # reformulate to x != a where x is variable and a a constant
        rhs = set.value / fct.terms[1].coefficient
        if isapprox_discrete(com, rhs)
            rhs = get_approx_discrete(rhs)
            v = com.search_space[fct.terms[1].variable.value]
            if has(v, rhs) 
                rm!(com, v, rhs; changes = false)
            end
        end
        return MOI.ConstraintIndex{SAF{T},CPE.DifferentFrom{T}}(0)
    end

    lc = new_linear_constraint(model.inner, fct, set)

    add_constraint!(model, lc)

    return MOI.ConstraintIndex{SAF{T},CPE.DifferentFrom{T}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::SAF{T},
    set::CPE.Strictly{MOI.LessThan{T}},
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
) where {A,T<:Real,ASS<:MOI.AbstractScalarSet,IS<:MOI.Indicator{A,ASS}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    indices = get_indices(func)

    internals = ConstraintInternals(
        length(com.constraints)+1,
        func,
        MOI.Indicator{A}(set.set),
        indices,
    )

    activator_internals = get_activator_internals(A, indices)

    lc = get_inner_constraint(com, func, set, set.set)

    constraint = IndicatorConstraint(internals, activator_internals, lc)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},MOI.Indicator{A,ASS}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::IS,
) where {A,F,S,IS<:CS.Indicator{A,F,S}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    internals = create_internals(com, vars, set)

    inner_constraint = get_inner_constraint(com, vars, set, set.set)

    indices = internals.indices
    activator_internals = get_activator_internals(A, indices)
    constraint =
        IndicatorConstraint(internals, activator_internals, inner_constraint)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{MOI.VectorOfVariables,CS.Indicator{A,F,S}}(length(com.constraints))
end


function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::IS,
) where {T,A,F,S<:MOI.AbstractVectorSet,IS<:CS.Indicator{A,F,S}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    internals = create_internals(com, func, set)

    inner_constraint = get_inner_constraint(com, func, set, set.set)
    indices = internals.indices

    activator_internals = get_activator_internals(A, indices)

    constraint =
        IndicatorConstraint(internals, activator_internals, inner_constraint)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},CS.Indicator{A,F,S}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::RS,
) where {A,F,S,T<:Real,RS<:Reified{A,F,S}}
    com = model.inner
    com.info.n_constraint_types.reified += 1

    indices = get_indices(func)

    internals = ConstraintInternals(
        length(com.constraints)+1,
        func,
        typeof(set)(set.set, set.dimension),
        indices,
    )

    inner = get_inner_constraint(com, func, set, set.set)
    complement_inner = get_complement_constraint(com, inner)

    activator_internals = get_activator_internals(A, indices)
    constraint = ReifiedConstraint(internals, activator_internals, inner, complement_inner)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},CS.Reified{A,F,S}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::RS,
) where {A,F,S<:MOI.AbstractVectorSet,RS<:CS.Reified{A,F,S}}
    com = model.inner
    com.info.n_constraint_types.reified += 1
    internals = create_internals(com, vars, set)

    inner_constraint = get_inner_constraint(com, vars, set, set.set)
    complement_constraint = get_complement_constraint(model, inner_constraint)
    indices = internals.indices
    activator_internals = get_activator_internals(A, indices)
    constraint =
        ReifiedConstraint(internals, activator_internals, inner_constraint, complement_constraint)

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{MOI.VectorOfVariables,CS.Reified{A,F,S}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::BS,
) where {T,BS<:AbstractBoolSet}
    com = model.inner
    internals = create_internals(com, func, set)
    constraint = init_constraint_struct(com, set, internals)
    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},typeof(set)}(length(com.constraints))
end

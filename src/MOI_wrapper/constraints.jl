"""
JuMP constraints
"""
sense_to_set(::Function, ::Val{:!=}) = NotEqualTo(0.0)

MOIU.shift_constant(set::NotEqualTo, value) = NotEqualTo(set.value + value)

"""
    Support for indicator constraints with a set constraint as the right hand side
"""
function JuMP._build_indicator_constraint(
    _error::Function,
    variable::JuMP.AbstractVariableRef,
    jump_constraint::JuMP.VectorConstraint,
    ::Type{MOI.IndicatorSet{A}},
) where {A}

    set = CS.IndicatorSet{A}(
        jump_constraint.set,
        1 + length(jump_constraint.func),
    )
    vov = VariableRef[variable]
    append!(vov, jump_constraint.func)
    return JuMP.VectorConstraint(vov, set)
end

include("reified.jl")



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

function MOI.supports_constraint(
    ::Optimizer,
    func::Type{VAF{T}},
    set::Type{IS},
) where {A,T<:Real,ASS<:MOI.AbstractScalarSet,IS<:MOI.IndicatorSet{A,ASS}}
    if ASS <: MOI.GreaterThan
        return false
    end
    return A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO
end

function MOI.supports_constraint(
    ::Optimizer,
    func::Type{MOI.VectorOfVariables},
    set::Type{IS},
) where {A,IS<:CS.IndicatorSet{A}}
    return A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO
end

function MOI.supports_constraint(
    ::Optimizer,
    func::Union{Type{VAF{T}},Type{MOI.VectorOfVariables}},
    set::Type{RS},
) where {A,T<:Real,IS,RS<:CS.ReifiedSet{A,IS}}
    if IS <: MOI.GreaterThan
        return false
    end
    return A == MOI.ACTIVATE_ON_ONE || A == MOI.ACTIVATE_ON_ZERO
end

MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{GeqSetInternal},
) = true


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
    add_constraint!(model.inner, constraint; set_pvals=false)
end

"""
    new_linear_constraint(model::Optimizer, func::SAF{T}, set) where {T<:Real}

Create a new linear constraint and return a `LinearConstraint` with already a correct index
such that it can be simply added with [`add_constraint!`](@ref)
"""
function new_linear_constraint(model::Optimizer, func::SAF{T}, set) where {T<:Real}
    indices = [v.variable_index.value for v in func.terms]

    lc_idx = length(model.inner.constraints) + 1
    lc = LinearConstraint(lc_idx, func, set, indices)
    return lc
end

"""
    create_interals(com::CoM, vars::MOI.VectorOfVariables, set)

Create ConstraintInternals for a vector of variables constraint
"""
function create_interals(com::CoM, vars::MOI.VectorOfVariables, set)
    ConstraintInternals(
        length(com.constraints) + 1,
        vars,
        set,
        Int[v.value for v in vars.variables],
    )
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

    constraint = init_constraint_struct(typeof(set), internals)

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

    lc = new_linear_constraint(model, func, set)

    add_constraint!(model, lc)
    model.inner.info.n_constraint_types.equality += 1

    return MOI.ConstraintIndex{SAF{T},MOI.EqualTo{T}}(length(model.inner.constraints))
end

function add_variable_less_than_variable_constraint(
    model::Optimizer,
    func::SAF{T},
    set::MOI.LessThan{T}
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
    set::MOI.LessThan{T}
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

    lc = new_linear_constraint(model, func, set)

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

    lc = new_linear_constraint(model, func, set)

    add_constraint!(model, lc)

    return MOI.ConstraintIndex{SAF{T},NotEqualTo{T}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::IS,
) where {A,T<:Real,ASS<:MOI.AbstractScalarSet,IS<:MOI.IndicatorSet{A,ASS}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    indices = [v.scalar_term.variable_index.value for v in func.terms]

    # for normal linear constraints
    inner_indices =
        [v.scalar_term.variable_index.value for v in func.terms if v.output_index == 2]
    inner_terms = [v.scalar_term for v in func.terms if v.output_index == 2]
    inner_constant = func.constants[2]
    inner_set = set.set

    inner_func = MOI.ScalarAffineFunction{T}(inner_terms, inner_constant)

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        func,
        MOI.IndicatorSet{A}(inner_set),
        indices,
    )

    lc = LinearConstraint(0, inner_func, inner_set, inner_indices)

    constraint = IndicatorConstraint(internals, A, lc, indices[1] in indices[2:end])

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},MOI.IndicatorSet{A,ASS}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::IS,
) where {A,IS<:CS.IndicatorSet{A}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    internals = create_interals(com, vars, set)

    inner_internals = ConstraintInternals(
        0,
        MOI.VectorOfVariables(vars.variables[2:end]),
        set.set,
        Int[v.value for v in vars.variables[2:end]],
    )
    inner_constraint = init_constraint_struct(typeof(set.set), inner_internals)

    indices = internals.indices
    constraint = IndicatorConstraint(internals, A, inner_constraint, indices[1] in indices[2:end])

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{MOI.VectorOfVariables,CS.IndicatorSet{A}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::RS,
) where {A,S,T<:Real,RS<:ReifiedSet{A,S}}
    com = model.inner
    com.info.n_constraint_types.reified += 1

    indices = [v.scalar_term.variable_index.value for v in func.terms]

    # for normal linear constraints
    inner_indices =
        [v.scalar_term.variable_index.value for v in func.terms if v.output_index == 2]
    inner_terms = [v.scalar_term for v in func.terms if v.output_index == 2]
    inner_constant = func.constants[2]
    inner_set = set.set

    inner_func = MOI.ScalarAffineFunction{T}(inner_terms, inner_constant)

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        func,
        ReifiedSet{A,S}(inner_set, set.dimension),
        indices,
    )

    lc = LinearConstraint(0, inner_func, inner_set, inner_indices)

    constraint = ReifiedConstraint(internals, A, lc, indices[1] in indices[2:end])

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{VAF{T},CS.ReifiedSet{A,S}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::RS,
) where {A,S,RS<:CS.ReifiedSet{A,S}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    internals = create_interals(com, vars, set)

    inner_internals = ConstraintInternals(
        0,
        MOI.VectorOfVariables(vars.variables[2:end]),
        set.set,
        Int[v.value for v in vars.variables[2:end]],
    )
    inner_constraint = init_constraint_struct(typeof(set.set), inner_internals)

    indices = internals.indices
    constraint = ReifiedConstraint(internals, A, inner_constraint, indices[1] in indices[2:end])

    add_constraint!(model, constraint)

    return MOI.ConstraintIndex{MOI.VectorOfVariables,CS.ReifiedSet{A,S}}(length(com.constraints))
end

"""
    set_pvals!(model::CS.Optimizer)

Set the possible values for each constraint.
"""
function set_pvals!(model::CS.Optimizer)
    com = model.inner
    for constraint in com.constraints
        set_pvals!(com, constraint)
    end
end

"""
    init_constraints!(com::CS.CoM; constraints=com.constraints)

Initializes all `constraints` which implement the `init_constraint!` function.
Return if feasible after initalization
"""
function init_constraints!(com::CS.CoM; constraints = com.constraints)
    feasible = true
    for constraint in constraints
        if constraint.impl.init
            feasible = init_constraint!(com, constraint, constraint.fct, constraint.set)
            !feasible && break
        end
        constraint.is_initialized = true
    end
    return feasible
end

"""
    init_constraints!(com::CS.CoM; constraints=com.constraints)

Initializes all constraints of the model as new `constraints` were added.
Return if feasible after the update of the initalization
"""
function update_init_constraints!(com::CS.CoM; constraints = com.constraints)
    feasible = true
    for constraint in com.constraints
        if constraint.impl.update_init
            feasible = update_init_constraint!(
                com,
                constraint,
                constraint.fct,
                constraint.set,
                constraints,
            )
            !feasible && break
        end
    end
    return feasible
end

"""
    set_impl_functions!(com, constraint::Constraint)

Set std.impl.[] for each constraint
"""
function set_impl_functions!(com, constraint::Constraint)
    if com.sense != MOI.FEASIBILITY_SENSE
        set_impl_update_best_bound!(constraint)
    end
    set_impl_init!(constraint)
    set_impl_update_init!(constraint)
    set_impl_finished_pruning!(constraint)
    set_impl_restore_pruning!(constraint)
    set_impl_reverse_pruning!(constraint)
end

"""
    set_impl_functions!(com::CS.CoM)

Set std.impl.[] for each constraint
"""
function set_impl_functions!(com::CS.CoM; constraints = com.constraints)
    for constraint in constraints
        set_impl_functions!(com, constraint)
    end
end

"""
    set_impl_init!(constraint::Constraint)
Sets `std.impl.init` if the constraint type has a `init_constraint!` method
"""
function set_impl_init!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(init_constraint!, (CS.CoM, c_type, c_fct_type, c_set_type))
        constraint.impl.init = true
    end
end

"""
    set_impl_update_init!(constraint::Constraint)
Sets `std.impl.update_init` if the constraint type has a `update_init_constraint!` method
"""
function set_impl_update_init!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(
        update_init_constraint!,
        (CS.CoM, c_type, c_fct_type, c_set_type, Vector{<:Constraint}),
    )
        constraint.impl.update_init = true
    end
end

"""
    set_impl_update_best_bound!(constraint::Constraint)

Sets `update_best_bound` if the constraint type has a `update_best_bound_constraint!` method
"""
function set_impl_update_best_bound!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(
        update_best_bound_constraint!,
        (CS.CoM, c_type, c_fct_type, c_set_type, Int, Int, Int),
    )
        constraint.impl.update_best_bound = true
    else # just to be sure => set it to false otherwise
        constraint.impl.update_best_bound = false
    end
end

"""
    set_impl_reverse_pruning!(constraint::Constraint)
Sets `std.impl.single_reverse_pruning` and `std.impl.reverse_pruning`
if `single_reverse_pruning_constraint!`, `reverse_pruning_constraint!` are implemented for `constraint`.
"""
function set_impl_reverse_pruning!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(
        single_reverse_pruning_constraint!,
        (CS.CoM, c_type, c_fct_type, c_set_type, CS.Variable, Int),
    )
        constraint.impl.single_reverse_pruning = true
    else # just to be sure => set it to false otherwise
        constraint.impl.single_reverse_pruning = false
    end

    if hasmethod(reverse_pruning_constraint!, (CS.CoM, c_type, c_fct_type, c_set_type, Int))
        constraint.impl.reverse_pruning = true
    else # just to be sure => set it to false otherwise
        constraint.impl.reverse_pruning = false
    end
end

"""
    set_impl_finished_pruning!(constraint::Constraint)
Sets `std.impl.finished_pruning` if `finished_pruning_constraint!`  is implemented for `constraint`.
"""
function set_impl_finished_pruning!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(finished_pruning_constraint!, (CS.CoM, c_type, c_fct_type, c_set_type))
        constraint.impl.finished_pruning = true
    else # just to be sure => set it to false otherwise
        constraint.impl.finished_pruning = false
    end
end

"""
    set_impl_restore_pruning!(constraint::Constraint)
Sets `std.impl.restore_pruning` if `restore_pruning_constraint!`  is implemented for the `constraint`.
"""
function set_impl_restore_pruning!(constraint::Constraint)
    c_type = typeof(constraint)
    c_fct_type = typeof(constraint.fct)
    c_set_type = typeof(constraint.set)
    if hasmethod(
        restore_pruning_constraint!,
        (CS.CoM, c_type, c_fct_type, c_set_type, Union{Int,Vector{Int}}),
    )
        constraint.impl.restore_pruning = true
    else # just to be sure => set it to false otherwise
        constraint.impl.restore_pruning = false
    end
end

"""
    call_finished_pruning!(com)

Call `finished_pruning_constraint!` for every constraint which implements that function as saved in `constraint.impl.finished_pruning`
"""
function call_finished_pruning!(com)
    for constraint in com.constraints
        if constraint.impl.finished_pruning
            finished_pruning_constraint!(com, constraint, constraint.fct, constraint.set)
        end
    end
end

"""
    call_restore_pruning!(com, prune_steps)

Call `call_restore_pruning!` for every constraint which implements that function as saved in `constraint.impl.restore_pruning`
"""
function call_restore_pruning!(com, prune_steps)
    for constraint in com.constraints
        if constraint.impl.restore_pruning
            restore_pruning_constraint!(
                com,
                constraint,
                constraint.fct,
                constraint.set,
                prune_steps,
            )
        end
    end
end

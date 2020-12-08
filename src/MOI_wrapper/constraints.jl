"""
JuMP constraints
"""
sense_to_set(::Function, ::Val{:!=}) = NotEqualTo(0.0)

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
        MOI.VectorOfVariables(jump_constraint.func),
        jump_constraint.set,
        1 + length(jump_constraint.func),
    )
    vov = VariableRef[variable]
    append!(vov, jump_constraint.func)
    return JuMP.VectorConstraint(vov, set)
end

include("reified.jl")

### !=

MOIU.shift_constant(set::NotEqualTo, value) = NotEqualTo(set.value + value)

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
) where {A,T<:Real,RS<:CS.ReifiedSet{A}}
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

            push!(com.constraints, constraint)
            for (i, vidx) in enumerate(constraint.indices)
                push!(com.subscription[vidx], constraint.idx)
            end
            com.info.n_constraint_types.equality += 1
            return MOI.ConstraintIndex{SAF{T},MOI.EqualTo{T}}(length(model.inner.constraints))
        end
    end

    indices = [v.variable_index.value for v in func.terms]

    lc_idx = length(model.inner.constraints) + 1
    lc = LinearConstraint(lc_idx, func, set, indices)

    push!(model.inner.constraints, lc)

    for (i, vidx) in enumerate(lc.indices)
        push!(model.inner.subscription[vidx], lc.idx)
    end
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

    push!(model.inner.constraints, svc)

    push!(model.inner.subscription[svc.lhs], svc.idx)
    push!(model.inner.subscription[svc.rhs], svc.idx)
    com.info.n_constraint_types.inequality += 1

    return MOI.ConstraintIndex{SAF{T},MOI.LessThan{T}}(length(model.inner.constraints))
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

    # for normal <= constraints
    indices = [v.variable_index.value for v in func.terms]

    lc_idx = length(model.inner.constraints) + 1
    lc = LinearConstraint(lc_idx, func, set, indices)

    push!(model.inner.constraints, lc)

    for (i, vidx) in enumerate(lc.indices)
        push!(model.inner.subscription[vidx], lc.idx)
    end
    model.inner.info.n_constraint_types.inequality += 1

    return MOI.ConstraintIndex{SAF{T},MOI.LessThan{T}}(length(model.inner.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::EqualSetInternal,
)
    com = model.inner

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        vars,
        set,
        Int[v.value for v in vars.variables],
    )
    constraint = EqualConstraint(internals, ones(Int, length(vars.variables)))

    push!(com.constraints, constraint)
    for (i, vidx) in enumerate(constraint.indices)
        push!(com.subscription[vidx], constraint.idx)
    end
    com.info.n_constraint_types.equality += 1

    return MOI.ConstraintIndex{MOI.VectorOfVariables,EqualSetInternal}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::AllDifferentSetInternal,
)
    com = model.inner

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        vars,
        set,
        Int[v.value for v in vars.variables],
    )

    constraint = init_constraint_struct(AllDifferentSetInternal, internals)

    push!(com.constraints, constraint)
    for (i, vidx) in enumerate(constraint.indices)
        push!(com.subscription[vidx], constraint.idx)
    end
    com.info.n_constraint_types.alldifferent += 1

    return MOI.ConstraintIndex{MOI.VectorOfVariables,AllDifferentSetInternal}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::TableSetInternal,
)
    com = model.inner

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        vars,
        set,
        Int[v.value for v in vars.variables],
    )

    constraint = init_constraint_struct(TableSetInternal, internals)

    push!(com.constraints, constraint)
    for (i, vidx) in enumerate(constraint.indices)
        push!(com.subscription[vidx], constraint.idx)
    end
    com.info.n_constraint_types.table += 1

    return MOI.ConstraintIndex{MOI.VectorOfVariables,TableSetInternal}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::GeqSetInternal,
)
    com = model.inner

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        vars,
        set,
        Int[v.value for v in vars.variables],
    )

    constraint = init_constraint_struct(GeqSetInternal, internals)

    push!(com.constraints, constraint)
    for (i, vidx) in enumerate(constraint.indices)
        push!(com.subscription[vidx], constraint.idx)
    end

    return MOI.ConstraintIndex{MOI.VectorOfVariables,GeqSetInternal}(length(com.constraints))
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

    indices = [v.variable_index.value for v in func.terms]

    lc_idx = length(model.inner.constraints) + 1
    lc = LinearConstraint(lc_idx, func, set, indices)

    push!(com.constraints, lc)
    for (i, vidx) in enumerate(lc.indices)
        push!(com.subscription[vidx], lc.idx)
    end

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
    if ASS isa Type{MOI.GreaterThan{T}}
        inner_terms = [
            MOI.ScalarAffineTerm(-v.scalar_term.coefficient, v.scalar_term.variable_index) for v in func.terms if v.output_index == 2
        ]
        inner_constant = -inner_constant
        inner_set = MOI.LessThan{T}(-set.set.lower)
    end
    inner_func = MOI.ScalarAffineFunction{T}(inner_terms, inner_constant)

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        func,
        MOI.IndicatorSet{A}(inner_set),
        indices,
    )

    lc = LinearConstraint(0, inner_func, inner_set, inner_indices)

    con = IndicatorConstraint(internals, A, lc, indices[1] in indices[2:end])

    push!(com.constraints, con)
    for (i, vidx) in enumerate(con.indices)
        push!(com.subscription[vidx], con.idx)
    end

    return MOI.ConstraintIndex{VAF{T},MOI.IndicatorSet{A,ASS}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::IS,
) where {A,IS<:CS.IndicatorSet{A}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    indices = Int[v.value for v in vars.variables]
    internals = ConstraintInternals(length(com.constraints) + 1, vars, set, indices)

    inner_internals = ConstraintInternals(
        0,
        MOI.VectorOfVariables(vars.variables[2:end]),
        set.set,
        Int[v.value for v in vars.variables[2:end]],
    )
    inner_constraint = init_constraint_struct(typeof(set.set), inner_internals)

    con = IndicatorConstraint(internals, A, inner_constraint, indices[1] in indices[2:end])

    push!(com.constraints, con)
    for (i, vidx) in enumerate(con.indices)
        push!(com.subscription[vidx], con.idx)
    end

    return MOI.ConstraintIndex{MOI.VectorOfVariables,CS.IndicatorSet{A}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    func::VAF{T},
    set::RS,
) where {A,T<:Real,RS<:ReifiedSet{A}}
    com = model.inner
    com.info.n_constraint_types.reified += 1

    indices = [v.scalar_term.variable_index.value for v in func.terms]

    # for normal linear constraints
    inner_indices =
        [v.scalar_term.variable_index.value for v in func.terms if v.output_index == 2]
    inner_terms = [v.scalar_term for v in func.terms if v.output_index == 2]
    inner_constant = func.constants[2]
    inner_set = set.set

    if typeof(set.set) isa Type{MOI.GreaterThan{T}}
        inner_terms = [
            MOI.ScalarAffineTerm(-v.scalar_term.coefficient, v.scalar_term.variable_index) for v in func.terms if v.output_index == 2
        ]
        inner_constant = -inner_constant
        inner_set = MOI.LessThan{T}(-set.set.lower)
    end
    inner_func = MOI.ScalarAffineFunction{T}(inner_terms, inner_constant)

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        func,
        ReifiedSet{A}(set.func, inner_set, set.dimension),
        indices,
    )

    lc = LinearConstraint(0, inner_func, inner_set, inner_indices)

    con = ReifiedConstraint(internals, A, lc, indices[1] in indices[2:end])

    push!(com.constraints, con)
    for (i, vidx) in enumerate(con.indices)
        push!(com.subscription[vidx], con.idx)
    end

    return MOI.ConstraintIndex{VAF{T},CS.ReifiedSet{A}}(length(com.constraints))
end

function MOI.add_constraint(
    model::Optimizer,
    vars::MOI.VectorOfVariables,
    set::IS,
) where {A,IS<:CS.ReifiedSet{A}}
    com = model.inner
    com.info.n_constraint_types.indicator += 1

    indices = Int[v.value for v in vars.variables]
    internals = ConstraintInternals(length(com.constraints) + 1, vars, set, indices)

    inner_internals = ConstraintInternals(
        0,
        MOI.VectorOfVariables(vars.variables[2:end]),
        set.set,
        Int[v.value for v in vars.variables[2:end]],
    )
    inner_constraint = init_constraint_struct(typeof(set.set), inner_internals)

    con = ReifiedConstraint(internals, A, inner_constraint, indices[1] in indices[2:end])

    push!(com.constraints, con)
    for (i, vidx) in enumerate(con.indices)
        push!(com.subscription[vidx], con.idx)
    end

    return MOI.ConstraintIndex{MOI.VectorOfVariables,CS.ReifiedSet{A}}(length(com.constraints))
end

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

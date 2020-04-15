"""
JuMP constraints
"""
sense_to_set(::Function, ::Val{:!=}) = NotEqualSet(0.0)

### !=

MOIU.shift_constant(set::NotEqualSet, value) = NotEqualSet(set.value + value)

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
# currently only a <= b is supported
MOI.supports_constraint(
    ::Optimizer,
    ::Type{SAF{T}},
    ::Type{MOI.LessThan{T}},
) where {T<:Real} = true

MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{EqualSet}) = true
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
        fix!(
            model.inner,
            model.variable_info[func.terms[1].variable_index.value],
            convert(Int, set.value / func.terms[1].coefficient);
            check_feasibility = false
        )
        return MOI.ConstraintIndex{SAF{T},MOI.EqualTo{T}}(0)
    end

    indices = [v.variable_index.value for v in func.terms]

    lc = LinearConstraint(func, set, indices)
    lc.std.idx = length(model.inner.constraints) + 1

    push!(model.inner.constraints, lc)

    for (i, ind) in enumerate(lc.std.indices)
        push!(model.inner.subscription[ind], lc.std.idx)
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
        length(model.inner.constraints) + 1, # idx
        func,
        set,
        [lhs, rhs]
    )
    svc = SingleVariableConstraint(
        internals,
        lhs,
        rhs
    )

    push!(model.inner.constraints, svc)

    push!(model.inner.subscription[svc.lhs], svc.std.idx)
    push!(model.inner.subscription[svc.rhs], svc.std.idx)
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
    if set.upper == 0.0 && length(func.terms) == 2 &&
       abs(func.terms[1].coefficient) == 1.0 && abs(func.terms[2].coefficient) == 1.0 &&
       func.terms[1].coefficient == -func.terms[2].coefficient
        return add_variable_less_than_variable_constraint(model, func, set)
    end

    # for normal <= constraints 
    indices = [v.variable_index.value for v in func.terms]

    lc = LinearConstraint(func, set, indices)
    lc.std.idx = length(model.inner.constraints) + 1

    push!(model.inner.constraints, lc)

    for (i, ind) in enumerate(lc.std.indices)
        push!(model.inner.subscription[ind], lc.std.idx)
    end
    model.inner.info.n_constraint_types.inequality += 1

    return MOI.ConstraintIndex{SAF{T},MOI.LessThan{T}}(length(model.inner.constraints))
end

function MOI.add_constraint(model::Optimizer, vars::MOI.VectorOfVariables, set::EqualSet)
    com = model.inner

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        vars,
        set,
        Int[v.value for v in vars.variables]
    )
    constraint = BasicConstraint(
       internals
    )

    push!(com.constraints, constraint)
    for (i, ind) in enumerate(constraint.std.indices)
        push!(com.subscription[ind], constraint.std.idx)
    end
    com.info.n_constraint_types.equality += 1

    return MOI.ConstraintIndex{MOI.VectorOfVariables,EqualSet}(length(com.constraints))
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
        Int[v.value for v in vars.variables]
    )

    constraint = AllDifferentConstraint(
        internals,
        Int[], # pval_mapping will be filled later
        Int[], # vertex_mapping => later
        Int[], # vertex_mapping_bw => later
        Int[], # di_ei => later
        Int[], # di_ej => later
        MatchingInit(),
        Int[]
    )

    push!(com.constraints, constraint)
    for (i, ind) in enumerate(constraint.std.indices)
        push!(com.subscription[ind], constraint.std.idx)
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
        Int[v.value for v in vars.variables]
    )

    constraint = TableConstraint(
        internals,
        RSparseBitSet(),
        TableSupport(), # will be filled in init_constraint!
        Int[], # will be changes later as it needs the number of words
        TableResidues(),
        Int[], # changed_vars
        Int[]  # unfixed_vars
    )

    push!(com.constraints, constraint)
    for (i, ind) in enumerate(constraint.std.indices)
        push!(com.subscription[ind], constraint.std.idx)
    end
    com.info.n_constraint_types.table += 1

    return MOI.ConstraintIndex{MOI.VectorOfVariables,TableSetInternal}(length(com.constraints))
end

MOI.supports_constraint(
    ::Optimizer,
    ::Type{SAF{T}},
    ::Type{NotEqualSet{T}},
) where {T<:Real} = true

function MOI.add_constraint(
    model::Optimizer,
    aff::SAF{T},
    set::NotEqualSet{T},
) where {T<:Real}
    com = model.inner
    com.info.n_constraint_types.notequal += 1

    # support for cx != a where a and c are constants
    if length(aff.terms) == 1
        # reformulate to x != a where x is variable and a a constant
        rhs = set.value / aff.terms[1].coefficient
        if isapprox_discrete(com, rhs)
            rhs = get_approx_discrete(rhs)
            rm!(
                com,
                com.search_space[aff.terms[1].variable_index.value],
                rhs;
                changes = false,
            )
        end
        return MOI.ConstraintIndex{SAF{T},NotEqualSet{T}}(0)
    end

    internals = ConstraintInternals(
        length(com.constraints) + 1,
        aff,
        set,
        Int[t.variable_index.value for t in aff.terms]
    )
    constraint = BasicConstraint(
        internals
    )

    push!(com.constraints, constraint)
    for (i, ind) in enumerate(constraint.std.indices)
        push!(com.subscription[ind], constraint.std.idx)
    end

    return MOI.ConstraintIndex{SAF{T},NotEqualSet{T}}(length(com.constraints))
end

function set_pvals!(model::CS.Optimizer)
    com = model.inner
    for constraint in com.constraints
        set_pvals!(com, constraint)
    end
end

function set_constraint_hashes!(com::CS.CoM)
    for ci = 1:length(com.constraints)
        com.constraints[ci].std.hash = constraint_hash(com.constraints[ci])
    end
end

function init_constraints!(com::CS.CoM; constraints=com.constraints)
    feasible = true
    for constraint in constraints
        c_type = typeof(constraint)
        c_fct_type = typeof(constraint.std.fct)
        c_set_type = typeof(constraint.std.set)
        if hasmethod(init_constraint!, (CS.CoM, c_type, c_fct_type, c_set_type))
            feasible = init_constraint!(com, constraint, constraint.std.fct, constraint.std.set)
            !feasible && break
        end
    end
    return feasible
end

"""	
    set_enforce_bound!(com::CS.CoM)	
Sets `enforce_bound` in each constraint if we have an objective function and:	
- the constraint type has a function `update_best_bound_constraint!`	
"""	
function set_enforce_bound!(com::CS.CoM)	
    if com.sense == MOI.FEASIBILITY_SENSE	
        return	
    end	
    objective_type = typeof(com.objective)	
    for ci = 1:length(com.constraints)	
        constraint = com.constraints[ci]	
        c_type = typeof(constraint)	
        c_fct_type = typeof(constraint.std.fct)	
        c_set_type = typeof(constraint.std.set)	
        if hasmethod(	
            update_best_bound_constraint!,	
            (CS.CoM, c_type, c_fct_type, c_set_type, Int, Int, Int),	
        )	
            constraint.std.enforce_bound = true	
        else # just to be sure => set it to false otherwise	
            constraint.std.enforce_bound = false	
        end	
    end	
end



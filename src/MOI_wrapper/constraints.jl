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
            convert(Int, set.value / func.terms[1].coefficient),
        )
        return MOI.ConstraintIndex{SAF{T},MOI.EqualTo{T}}(0)
    end

    indices = [v.variable_index.value for v in func.terms]

    lc = LinearConstraint(func, set, indices)
    lc.idx = length(model.inner.constraints) + 1

    push!(model.inner.constraints, lc)

    for (i, ind) in enumerate(lc.indices)
        push!(model.inner.subscription[ind], lc.idx)
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

    svc = SingleVariableConstraint(
        length(model.inner.constraints) + 1, # idx
        func,
        set,
        [lhs, rhs],
        Int[], # pvals
        lhs,
        rhs,
        false, # `enforce_bound` can be changed later but should be set to false by default
        zero(UInt64), # will be filled later
    )

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
    if set.upper == 0.0 && length(func.terms) == 2 &&
       abs(func.terms[1].coefficient) == 1.0 && abs(func.terms[2].coefficient) == 1.0 &&
       func.terms[1].coefficient == -func.terms[2].coefficient
        return add_variable_less_than_variable_constraint(model, func, set)
    end

    # for normal <= constraints 
    indices = [v.variable_index.value for v in func.terms]

    lc = LinearConstraint(func, set, indices)
    lc.idx = length(model.inner.constraints) + 1

    push!(model.inner.constraints, lc)

    for (i, ind) in enumerate(lc.indices)
        push!(model.inner.subscription[ind], lc.idx)
    end
    model.inner.info.n_constraint_types.inequality += 1

    return MOI.ConstraintIndex{SAF{T},MOI.LessThan{T}}(length(model.inner.constraints))
end

MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{EqualSet}) = true
MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorOfVariables},
    ::Type{AllDifferentSetInternal},
) = true

function MOI.add_constraint(model::Optimizer, vars::MOI.VectorOfVariables, set::EqualSet)
    com = model.inner

    constraint = BasicConstraint(
        length(com.constraints) + 1,
        vars,
        set,
        Int[v.value for v in vars.variables],
        Int[], # pvals will be filled later
        false, # `enforce_bound` can be changed later but should be set to false by default
        nothing, 
        zero(UInt64), # hash will be filled later
    )

    push!(com.constraints, constraint)
    for (i, ind) in enumerate(constraint.indices)
        push!(com.subscription[ind], constraint.idx)
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

    constraint = AllDifferentConstraint(
        length(com.constraints) + 1,
        vars,
        set,
        Int[v.value for v in vars.variables],
        Int[], # pvals will be filled later
        Int[], # pval_mapping will be filled later
        Int[], # vertex_mapping => later
        Int[], # vertex_mapping_bw => later
        Int[], # di_ei => later
        Int[], # di_ej => later
        MatchingInit(),
        false, # `enforce_bound` can be changed later but should be set to false by default
        nothing,
        zero(UInt64), # hash will be filled later
    )

    push!(com.constraints, constraint)
    for (i, ind) in enumerate(constraint.indices)
        push!(com.subscription[ind], constraint.idx)
    end
    com.info.n_constraint_types.alldifferent += 1

    return MOI.ConstraintIndex{MOI.VectorOfVariables,AllDifferentSetInternal}(length(com.constraints))
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

    constraint = BasicConstraint(
        length(com.constraints) + 1,
        aff,
        set,
        Int[t.variable_index.value for t in aff.terms],
        Int[], # pvals will be filled later
        false, # `enforce_bound` can be changed later but should be set to false by default
        nothing,
        zero(UInt64), # hash will be filled later
    )

    push!(com.constraints, constraint)
    for (i, ind) in enumerate(constraint.indices)
        push!(com.subscription[ind], constraint.idx)
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
        com.constraints[ci].hash = constraint_hash(com.constraints[ci])
    end
end

function init_constraints!(com::CS.CoM)
    for ci = 1:length(com.constraints)
        constraint = com.constraints[ci]
        c_type = typeof(constraint)
        c_fct_type = typeof(constraint.fct)
        c_set_type = typeof(constraint.set)
        if hasmethod(init_constraint!, (CS.CoM, c_type, c_fct_type, c_set_type))
            init_constraint!(com, constraint, constraint.fct, constraint.set)
        end
    end
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
        c_fct_type = typeof(constraint.fct)	
        c_set_type = typeof(constraint.set)	
        if hasmethod(	
            update_best_bound_constraint!,	
            (CS.CoM, c_type, c_fct_type, c_set_type, Int, Bool, Int),	
        )	
            constraint.enforce_bound = true	
        else # just to be sure => set it to false otherwise	
            constraint.enforce_bound = false	
        end	
    end	
end



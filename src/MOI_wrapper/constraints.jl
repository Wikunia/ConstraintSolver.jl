"""
MOI constraints
"""

"""
Linear constraints
"""
MOI.supports_constraint(::Optimizer, ::Type{SAF{T}}, ::Type{MOI.EqualTo{T}}) where T <: Real = true
# currently only a <= b is supported
MOI.supports_constraint(::Optimizer, ::Type{SAF{T}}, ::Type{MOI.LessThan{T}}) where T <: Real= true

function check_inbounds(model::Optimizer, aff::SAF{T}) where T <: Real
	for term in aff.terms
	    check_inbounds(model, term.variable_index)
	end
	return
end

function MOI.add_constraint(model::Optimizer, func::SAF{T}, set::MOI.EqualTo{T}) where T <: Real
    check_inbounds(model, func)

    if length(func.terms) == 1
        fix!(model.inner, model.variable_info[func.terms[1].variable_index.value], convert(Int, set.value/func.terms[1].coefficient))
        return MOI.ConstraintIndex{SAF{T}, MOI.EqualTo{T}}(0)
    end
   
    indices = [v.variable_index.value for v in func.terms]
    coeffs = [v.coefficient for v in func.terms]
    fct = eq_sum
    operator = :(==)
    rhs = set.value
    
    lc = LinearConstraint(fct, operator, indices, coeffs, rhs)
    lc.idx = length(model.inner.constraints)+1

    push!(model.inner.constraints, lc)

    for (i,ind) in enumerate(lc.indices)
        push!(model.inner.subscription[ind], lc.idx)
    end

    return MOI.ConstraintIndex{SAF{T}, MOI.EqualTo{T}}(length(model.inner.constraints))
end

# support for a <= b which is written as a-b <= 0
function MOI.add_constraint(model::Optimizer, func::SAF{T}, set::MOI.LessThan{T}) where T <: Real
    check_inbounds(model, func)

    if set.upper != 0.0
        error("Only constraints of the type `a <= b` are supported but not `a <= b-2`")
    end
    if length(func.terms) != 2
        error("Only constraints of the type `a <= b` are supported but not `a+b <= c` or something with more terms")
    end
    reverse_order = false
    if func.terms[1].coefficient != 1.0 || func.terms[2].coefficient != -1.0
        if func.terms[1].coefficient == -1.0 && func.terms[2].coefficient == 1.0
            # rhs is lhs and other way around
            reverse_order = true
        else
            error("Only constraints of the type `a <= b` are supported but not `2a <= b`. You used coefficients: $(func.terms[1].coefficient) and $(func.terms[2].coefficient) instead of `1.0` and `-1.0`")
        end
    end

    com = model.inner

    svc = SingleVariableConstraint()
    svc.fct = less_than
    if reverse_order
        svc.lhs = func.terms[2].variable_index.value
        svc.rhs = func.terms[1].variable_index.value
    else
        svc.lhs = func.terms[1].variable_index.value
        svc.rhs = func.terms[2].variable_index.value
    end
    svc.indices = [svc.lhs, svc.rhs]
    svc.idx = length(model.inner.constraints)+1

    push!(model.inner.constraints, svc)

    push!(model.inner.subscription[svc.lhs], svc.idx)
    push!(model.inner.subscription[svc.rhs], svc.idx)

    return MOI.ConstraintIndex{SAF{T}, MOI.LessThan{T}}(length(model.inner.constraints))
end


MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{AllDifferentSet}) = true

function MOI.add_constraint(model::Optimizer, vars::MOI.VectorOfVariables, set::AllDifferentSet)
    com = model.inner

    constraint = BasicConstraint()
    constraint.fct = all_different
    constraint.indices = Int[vi.value for vi in vars.variables]
    constraint.idx = length(com.constraints)+1

    push!(com.constraints, constraint)
    for (i,ind) in enumerate(constraint.indices)
        push!(com.subscription[ind], constraint.idx)
    end

    return MOI.ConstraintIndex{MOI.VectorOfVariables, AllDifferentSet}(length(com.constraints))
end

MOI.supports_constraint(::Optimizer, ::Type{SAF{T}}, ::Type{NotEqualSet{T}}) where T <: Real = true

function MOI.add_constraint(model::Optimizer, aff::SAF{T}, set::NotEqualSet{T}) where T <: Real 
    if set.value != 0.0
        error("Only constraints of the type `a != b` are supported but not `a != b-2`")
    end
    if length(aff.terms) != 2
        error("Only constraints of the type `a != b` are supported but not `[a,b,...] in NotEqualSet` => only two variables. Otherwise use an AllDifferentSet constraint.")
    end
    if aff.terms[1].coefficient != 1.0 || aff.terms[2].coefficient != -1.0
        error("Only constraints of the type `a != b` are supported but not `2a != b`. You used coefficients: $(aff.terms[1].coefficient) and $(aff.terms[2].coefficient) instead of `1.0` and `-1.0`")
    end

    com = model.inner

    constraint = BasicConstraint()
    constraint.fct = not_equal
    constraint.indices = Int[vi.variable_index.value for vi in aff.terms]
    constraint.idx = length(com.constraints)+1

    push!(com.constraints, constraint)
    for (i,ind) in enumerate(constraint.indices)
        push!(com.subscription[ind], constraint.idx)
    end

    return MOI.ConstraintIndex{SAF{T}, NotEqualSet{T}}(length(com.constraints))
end

function set_pvals!(model::CS.Optimizer)
    com = model.inner
    for constraint in com.constraints
        set_pvals!(com, constraint)
    end
end

function set_constraint_hashes!(model::CS.Optimizer)
    com = model.inner
    for ci=1:length(com.constraints)
        com.constraints[ci].hash = constraint_hash(com.constraints[ci])
    end
end

### !=

sense_to_set(::Function, ::Val{:!=}) = NotEqualSet(0.0)

MOIU.shift_constant(set::NotEqualSet, value) = NotEqualSet(set.value + value)

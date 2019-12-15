"""
MOI constraints
"""

"""
Linear constraints
"""
MOI.supports_constraint(::Optimizer, ::Type{SAF}, ::Type{MOI.EqualTo{Float64}}) = true

function check_inbounds(model::Optimizer, aff::SAF)
	for term in aff.terms
	    check_inbounds(model, term.variable_index)
	end
	return
end

function MOI.add_constraint(model::Optimizer, func::SAF, set::MOI.EqualTo{Float64})
    check_inbounds(model, func)
    
    if length(func.terms) == 1
        fix!(model.inner, model.variable_info[func.terms[1].variable_index.value], convert(Int64, set.value))
        return MOI.ConstraintIndex{SAF, MOI.EqualTo{Float64}}(0)
    end

    lc = LinearConstraint()
    indices = [v.variable_index.value for v in func.terms]
    coeffs = [v.coefficient for v in func.terms]
    println("indices: ", indices)
    println("rhs: ", set.value)
    lc.fct = eq_sum
    lc.indices = indices
    lc.coeffs = coeffs
    lc.operator = :(==)
    lc.rhs = set.value
    lc.maxs = zeros(Int, length(indices))
    lc.mins = zeros(Int, length(indices))
    lc.pre_maxs = zeros(Int, length(indices))
    lc.pre_mins = zeros(Int, length(indices))
    # this can be changed later in `set_in_all_different!` but needs to be initialized with false
    lc.in_all_different = false
    lc.idx = length(model.inner.constraints)+1

    push!(model.inner.constraints, lc)

    for (i,ind) in enumerate(lc.indices)
        push!(model.inner.subscription[ind], lc.idx)
    end

    return MOI.ConstraintIndex{SAF, MOI.EqualTo{Float64}}(length(model.inner.constraints))
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

function set_pvals!(model::CS.Optimizer)
    com = model.inner
    for constraint in com.constraints 
        set_pvals!(com, constraint)
    end
end
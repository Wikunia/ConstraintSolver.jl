MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{VI}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SAF{T}}) where {T<:Real} = true

"""
set and get function overloads
"""
MOI.get(model::Optimizer, ::MOI.ObjectiveSense) = model.inner.sense

function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    model.inner.sense = sense
    return
end

function MOI.set(model::Optimizer, ::MOI.ObjectiveFunction, func::VI)
    check_inbounds(model, func)
    model.inner.var_in_obj[func.variable.value] = true
    model.inner.objective =
        SingleVariableObjective(func, func.variable.value, [func.variable.value])
    return
end

function MOI.set(model::Optimizer, ::MOI.ObjectiveFunction, func::SAF{T}) where {T<:Real}
    check_inbounds(model, func)
    indices = [func.terms[i].variable.value for i in 1:length(func.terms)]
    coeffs = [func.terms[i].coefficient for i in 1:length(func.terms)]
    lc = LinearCombination(indices, coeffs)
    model.inner.var_in_obj[indices] .= true
    model.inner.objective = LinearCombinationObjective(func, lc, func.constant, indices)
    return
end

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SVF}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SAF{T}}) where T <: Real = true

"""
set and get function overloads
"""
MOI.get(model::Optimizer, ::MOI.ObjectiveSense) = model.inner.sense

function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    model.inner.sense = sense
    return
end

function MOI.set(model::Optimizer, ::MOI.ObjectiveFunction, func::SVF)
    check_inbounds(model, func)
    model.inner.objective = SingleVariableObjective(CS.single_variable_objective, func.variable.value, [func.variable.value])
    return
end

function MOI.set(model::Optimizer, ::MOI.ObjectiveFunction, func::SAF{T}) where T <: Real
    check_inbounds(model, func)
    indices = [func.terms[i].variable_index.value for i=1:length(func.terms)]
    coeffs  = [func.terms[i].coefficient for i=1:length(func.terms)]
    lc = LinearCombination(indices, coeffs)
    model.inner.objective = LinearCombinationObjective(CS.linear_combination_objective, lc, func.constant, indices)
    return
end

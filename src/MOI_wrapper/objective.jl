MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{SVF}) = true

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
    model.inner.objective = SingleVariableObjective(CS.single_variable_objective, func.variable.value)
    return
end
function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
	return model.status
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveValue)
    return model.inner.best_sol
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveBound)
    return model.inner.best_bound
end

function MOI.get(model::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex)
    check_inbounds(model, vi)
    return CS.value(model.inner.search_space[vi.value])
end

function set_status!(model::Optimizer, status::Symbol)
    if status == :Solved
        model.status = MOI.OPTIMAL
    elseif status == :Infeasible
        model.status = MOI.INFEASIBLE
    else
        model.status = MOI.OTHER_LIMIT
    end
end

function MOI.get(model::Optimizer, ::MOI.SolveTime)
    return model.inner.solve_time
end

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
	return model.status
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveValue)
    # if model.status == MOI.OPTIMIZE_NOT_CALLED
    #     @error "optimize! not called"
    # end
    return model.inner.best_sol
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveBound)
    # if model.status == MOI.OPTIMIZE_NOT_CALLED
    #     @error "optimize! not called"
    # end
    return model.inner.best_bound
end

function MOI.get(model::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex)
    if model.status == MOI.OPTIMIZE_NOT_CALLED
        @error "optimize! not called"
    end
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

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    return model.status
end

function MOI.get(model::Optimizer, ov::MOI.ObjectiveValue)
    return model.inner.solutions[ov.result_index].incumbent
end

function MOI.get(model::Optimizer, ::MOI.ObjectiveBound)
    return model.inner.best_bound
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    return length(model.inner.solutions)
end

function MOI.get(model::Optimizer, vp::MOI.VariablePrimal, vi::MOI.VariableIndex)
    check_inbounds(model, vi)
    return model.inner.solutions[vp.N].values[vi.value]
end

function set_status!(model::Optimizer, status::Symbol)
    if status == :Solved
        model.status = MOI.OPTIMAL
    elseif status == :Infeasible
        model.status = MOI.INFEASIBLE
    elseif status == :Time
        model.status = MOI.TIME_LIMIT
    else
        model.status = MOI.OTHER_LIMIT
    end
end

function MOI.get(model::Optimizer, ::MOI.SolveTime)
    return model.inner.solve_time
end

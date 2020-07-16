function create_lp_model!(model)
    model.options.lp_optimizer === nothing && return
    com = model.inner
    com.sense == MOI.FEASIBILITY_SENSE && return
    lp_model = Model()
    
    set_optimizer(lp_model, model.options.lp_optimizer)
    lp_x = Vector{VariableRef}(undef, length(com.search_space))
    for variable in com.search_space
        lp_x[variable.idx] = @variable(lp_model, lower_bound = variable.lower_bound, upper_bound = variable.upper_bound)
    end
    lp_backend = backend(lp_model)
    # iterate through all constraints and add all supported constraints
    for constraint in com.constraints
        if MOI.supports_constraint(model.options.lp_optimizer.optimizer_constructor(), typeof(constraint.std.fct), typeof(constraint.std.set))
            MOI.add_constraint(lp_backend, constraint.std.fct, constraint.std.set)
        end
    end
    # add objective
    !MOI.supports(lp_backend, MOI.ObjectiveSense()) && @error "The given lp solver doesn't allow objective functions"
    typeof_objective = typeof(com.objective.fct)
    if MOI.supports(lp_backend, MOI.ObjectiveFunction{typeof_objective}())
        MOI.set(lp_backend, MOI.ObjectiveFunction{typeof_objective}(), com.objective.fct)
    else 
        @error "The given `lp_optimizer` doesn't support the objective function $(typeof_objective)" 
    end
    if MOI.supports(lp_backend, MOI.ObjectiveSense())
        MOI.set(lp_backend, MOI.ObjectiveSense(), com.sense)
    else 
        @error "The given `lp_optimizer` doesn't support setting `ObjectiveSense`" 
    end
    com.lp_x = lp_x
    com.lp_model = lp_model
end

function create_lp_variable!(lp_model, lp_x; lb=typemin(Int64), ub=typemax(Int64))
    v = @variable(lp_model, lower_bound=lb, upper_bound=ub)
    push!(lp_x, v)
    return length(lp_x)
end

const SVF = MOI.SingleVariable
const SAF = MOI.ScalarAffineFunction

# indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

const VAR_TYPES = Union{MOI.ZeroOne,MOI.Integer}

"""
Optimizer struct
"""
mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::CS.ConstraintSolverModel
    variable_info::Vector{Variable}
    # which variable index, (:leq,:geq,:eq,:Int,:Bin), and lower and upper bound
    var_constraints::Vector{Tuple{Int,Symbol,Int,Int}}
    status::MOI.TerminationStatusCode
    options::SolverOptions
end

include("variables.jl")
include("constraints.jl")
include("objective.jl")
include("results.jl")

MOI.get(::Optimizer, ::MOI.SolverName) = "ConstraintSolver"

"""
Optimizer struct constructor
"""
function Optimizer(; options...)
    options = combine_options(options)
    com = CS.ConstraintSolverModel(options.solution_type)
    return Optimizer(com, [], [], MOI.OPTIMIZE_NOT_CALLED, options)
end

"""
    MOI.is_empty(model::Optimizer)
"""
function MOI.is_empty(model::Optimizer)
    return isempty(model.variable_info) && isempty(model.var_constraints)
end

"""
    MOI.empty!(model::Optimizer)
"""
function MOI.empty!(model::Optimizer)
    model.inner = CS.ConstraintSolverModel(model.options.solution_type)
    empty!(model.variable_info)
    empty!(model.var_constraints)
    model.status = MOI.OPTIMIZE_NOT_CALLED
    # !important => don't remove the options
end

"""
Copy constructor for the optimizer
"""
MOIU.supports_default_copy_to(model::Optimizer, copy_names::Bool) = !copy_names
function MOI.copy_to(model::Optimizer, src::MOI.ModelLike; kws...)
    return MOI.Utilities.automatic_copy_to(model, src; kws...)
end

MOI.supports(::Optimizer, ::MOI.RawParameter) = true

"""
    MOI.set(model::Optimizer, p::MOI.RawParameter, value)

Set a RawParameter to `value`
"""
function MOI.set(model::Optimizer, p::MOI.RawParameter, value)
    p_symbol = Symbol(p.name)
    if in(p_symbol, fieldnames(SolverOptions))
        type_of_param = fieldtype(SolverOptions, p_symbol)
        if hasmethod(convert, (Type{type_of_param}, typeof(value)))
            setfield!(model.options, p_symbol, convert(type_of_param, value))
        else
            @error "The option $(p.name) has a different type ($(type_of_param))"
        end
    else
        @error "The option $(p.name) doesn't exist."
    end
    return
end

function create_lp_model!(model)
    model.options.lp_optimizer === nothing && return
    com = model.inner
    com.sense == MOI.FEASIBILITY_SENSE && return
    lp_model = com.lp_model
    set_optimizer(lp_model, model.options.lp_optimizer)
    lp_x = Vector{VariableRef}(undef, length(com.search_space))
    for variable in com.search_space
        lp_x[variable.idx] = @variable(lp_model, lower_bound = variable.lower_bound, upper_bound = variable.upper_bound)
    end
    lp_backend = backend(lp_model);
    # iterate through all constraints and add all supported constraints
    for constraint in com.constraints
        if MOI.supports_constraint(model.options.lp_optimizer.optimizer_constructor(), typeof(constraint.fct), typeof(constraint.set))
            MOI.add_constraint(lp_backend, constraint.fct, constraint.set)
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
end

"""
    MOI.optimize!(model::Optimizer)
"""
function MOI.optimize!(model::Optimizer)
    # check if every variable has bounds and is an Integer
    check_var_bounds(model)

    set_pvals!(model)

    create_lp_model!(model)

    status = solve!(model)
    set_status!(model, status)
end


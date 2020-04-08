const SVF = MOI.SingleVariable
const SAF = MOI.ScalarAffineFunction

# indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

const VAR_TYPES = Union{MOI.ZeroOne,MOI.Integer}

var_idx(x::JuMP.VariableRef) = x.index.value
var_idx(x::MOI.VariableIndex) = x.value

# support for @variable(m, x, Set)
function JuMP.build_variable(_error::Function, info::JuMP.VariableInfo, set::T) where T<:MOI.AbstractScalarSet
    return JuMP.VariableConstrainedOnCreation(JuMP.ScalarVariable(info), set)
end


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
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

"""
    MOI.set(model::Optimizer, p::MOI.RawParameter, value)

Set a RawParameter to `value`
"""
function MOI.set(model::Optimizer, p::MOI.RawParameter, value)
    p_symbol = Symbol(p.name)
    if in(p_symbol, fieldnames(SolverOptions))
        type_of_param = fieldtype(SolverOptions, p_symbol)
        if hasmethod(convert, (Type{type_of_param}, typeof(value)))
            if is_possible_option_value(p, value)
                setfield!(model.options, p_symbol, convert(type_of_param, value))
            else
                @error "The option $(p_symbol) doesn't have $(value) as a possible value. Possible values are: $(POSSIBLE_OPTIONS[p_symbol])"
            end
        else
            @error "The option $(p.name) has a different type ($(type_of_param))"
        end
    else
        @error "The option $(p.name) doesn't exist."
    end
    return
end

"""
    MOI.set(model::Optimizer, ::MOI.RawParameter, value)

Set the time limit
"""
function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing, Float64})
    if value === nothing
        model.options.time_limit = Inf
    else
        model.options.time_limit = value
    end
    return
end

"""
    MOI.optimize!(model::Optimizer)
"""
function MOI.optimize!(model::Optimizer)
    # check if every variable has bounds and is an Integer
    check_var_bounds(model)

    set_pvals!(model)

    create_lp_model!(model)
    set_enforce_bound!(model.inner)

    status = solve!(model)
    set_status!(model, status)
end

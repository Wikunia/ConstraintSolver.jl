var_idx(x::JuMP.VariableRef) = JuMP.optimizer_index(x).value
var_idx(x::MOI.VariableIndex) = x.value
# support for @variable(m, x, Set)
function JuMP.build_variable(
    _error::Function,
    info::JuMP.VariableInfo,
    set::T,
) where {T<:MOI.AbstractScalarSet}
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

include("util.jl")
include("variables.jl")
include("Bridges/util.jl")
include("Bridges/indicator.jl")
include("Bridges/reified.jl")
include("Bridges/strictly_greater_than.jl")
include("Bridges/bool.jl")
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
    optimizer = Optimizer(com, [], [], MOI.OPTIMIZE_NOT_CALLED, options)
    lbo = MOIB.full_bridge_optimizer(optimizer, options.solution_type)
    greater2less_bridges = [
        MOIBC.GreaterToLessBridge{options.solution_type},
        CS.StrictlyGreaterToStrictlyLessBridge{options.solution_type}
    ]
    inner_bridges = greater2less_bridges
    # have inner them inside the BoolBridge
    push!(inner_bridges, CS.BoolBridge{options.solution_type, inner_bridges...})
  
    for inner_bridge in inner_bridges
        MOIB.add_bridge(lbo, inner_bridge)
        MOIB.add_bridge(lbo, CS.IndicatorBridge{options.solution_type, inner_bridge})
        MOIB.add_bridge(lbo, CS.ReifiedBridge{options.solution_type, inner_bridge})
    end
    return lbo
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
    return MOIU.automatic_copy_to(model, src; kws...)
end

MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

"""
    MOI.set(model::Optimizer, p::MOI.RawParameter, value)

Set a RawParameter to `value`
"""
function MOI.set(model::Optimizer, p::MOI.RawParameter, value)
    current_options_type = SolverOptions
    current_options_obj = model.options
    p_symbol = Symbol(p.name)

    # being able to parse simple options like "traverse_strategy"
    # as well as sub category options like "activity.decay"
    num_subcat = 0
    parts = split(p.name, ".")
    for pname in parts
        num_subcat += 1
        cp_symbol = Symbol(pname)
        if in(cp_symbol, fieldnames(current_options_type))
            type_of_param = fieldtype(current_options_type, cp_symbol)
            if num_subcat == length(parts)
                if hasmethod(convert, (Type{type_of_param}, typeof(value)))
                    if is_possible_option_value(p, value)
                        setfield!(
                            current_options_obj,
                            cp_symbol,
                            convert(type_of_param, value),
                        )
                    else
                        @error "The option $(cp_symbol) doesn't have $(value) as a possible value. Possible values are: $(POSSIBLE_OPTIONS[p_symbol])"
                        break
                    end
                else
                    @error "The option $(p.name) has a different type ($(type_of_param))"
                    break
                end
            else
                current_options_type = type_of_param
                current_options_obj = getfield(current_options_obj, cp_symbol)
            end
        else
            @error "The option $(p.name) doesn't exist."
            break
        end
    end
    return
end

"""
    MOI.set(model::Optimizer, ::MOI.RawParameter, value)

Set the time limit
"""
function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing,Float64})
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
    model.inner.options = model.options
    # check if every variable has bounds and is an Integer
    check_var_bounds(model)

    set_pvals!(model)
    set_var_in_all_different!(model)

    create_lp_model!(model)

    status = solve!(model.inner)
    set_status!(model, status)

    if status == :Solved
        com = model.inner
        com.solutions = unique!(sol -> sol.hash, com.solutions)
        if !com.options.all_solutions
            filter!(sol -> sol.incumbent == com.best_sol, com.solutions)
        end
        sort_solutions!(com)
    end
end

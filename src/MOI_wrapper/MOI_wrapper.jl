const SVF = MOI.SingleVariable
const SAF = MOI.ScalarAffineFunction{Float64}

# indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# sets
const BOUNDS = Union{
    MOI.EqualTo{Float64},
    MOI.GreaterThan{Float64},
    MOI.LessThan{Float64},
    MOI.Interval{Float64}
}

const VAR_TYPES = Union{
    MOI.ZeroOne,
    MOI.Integer
}

"""
Optimizer struct
"""
mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Union{CoM, Nothing}
    variable_info::Vector{Variable}
    # which variable index, (:leq,:geq,:eq,:Int,:Bin), and lower and upper bound
    var_constraints::Vector{Tuple{Int64,Symbol,Int64,Int64}}
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
function Optimizer(;options...)
    com = CS.ConstraintSolverModel()
    options = combine_options(options)
    return Optimizer(
        com,
        [],
        [],
        MOI.OPTIMIZE_NOT_CALLED,
        options
    )
end

"""
    MOI.is_empty(model::Optimizer)
"""
function MOI.is_empty(model::Optimizer)
    return isempty(model.variable_info) &&
           isempty(model.var_constraints)
end

"""
    MOI.empty!(model::Optimizer)
"""
function MOI.empty!(model::Optimizer)
    model.inner = CS.ConstraintSolverModel()
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

"""
    MOI.optimize!(model::Optimizer)
"""
function MOI.optimize!(model::Optimizer)
    # check if every variable has bounds and is an Integer
    check_var_bounds(model)

    set_pvals!(model)
    set_constraint_hashes!(model)

    status = solve!(model)
    set_status!(model, status)
end

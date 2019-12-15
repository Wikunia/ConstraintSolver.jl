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
    sense::MOI.OptimizationSense 
    objective::Union{Nothing, ObjectiveFunction}
    # which variable index, (:leq,:geq,:eq,:Int,:Bin), and lower and upper bound
    var_constraints::Vector{Tuple{Int64,Symbol,Int64,Int64}} 
end

include("variables.jl")
include("constraints.jl")

MOI.get(::Optimizer, ::MOI.SolverName) = "ConstraintSolver"

"""
Optimizer struct constructor 
"""
function Optimizer(;options...) 
    com = CS.init()
    return Optimizer(
        com, 
        [], 
        MOI.FEASIBILITY_SENSE, 
        nothing,
        []
    )
end 

"""
    MOI.is_empty(model::Optimizer)
"""
function MOI.is_empty(model::Optimizer)
    return isempty(model.variable_info) && 
           model.sense == MOI.FEASIBILITY_SENSE &&
           model.objective === nothing &&
           isempty(model.var_constraints)
end

"""
    MOI.empty!(model::Optimizer)
"""
function MOI.empty!(model::Optimizer)
    model.inner = CS.init()
    empty!(model.variable_info)
    model.sense = MOI.FEASIBILITY_SENSE
    model.objective = nothing
    empty!(model.var_constraints)
end

""" 
Copy constructor for the optimizer
"""
MOIU.supports_default_copy_to(model::Optimizer, copy_names::Bool) = true
function MOI.copy_to(model::Optimizer, src::MOI.ModelLike; kws...)
    return MOI.Utilities.automatic_copy_to(model, src; kws...)
end

"""
    MOI.optimize!(model::Optimizer)
""" 
function MOI.optimize!(model::Optimizer)
    # check if every variable has bounds and is an Integer
    check_var_bounds(model)
    # add all variables to the search space
    add_vars_to_model!(model)
    # set the pvals 
    set_pvals!(model)

    solve!(model.inner)

    println("Values:")
    for var in model.inner.search_space
        println("$(var.idx) => $(CS.value(var))")
    end
end


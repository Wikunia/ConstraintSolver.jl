mutable struct Variable
    idx::Int
    lower_bound::Int # inital lower and
    upper_bound::Int # upper bound of the variable see min, max otherwise
    first_ptr::Int
    last_ptr::Int
    values::Vector{Int}
    indices::Vector{Int}
    offset::Int
    min::Int # the minimum value during the solving process
    max::Int # for initial see lower/upper_bound
    changes::Vector{Vector{Tuple{Symbol,Int,Int,Int}}}
    has_upper_bound::Bool # must be true to work
    has_lower_bound::Bool # must be true to work
    is_fixed::Bool
    is_integer::Bool # must be true to work
end

mutable struct CSInfo
    pre_backtrack_calls::Int
    backtracked::Bool
    backtrack_fixes::Int
    in_backtrack_calls::Int
    backtrack_reverses::Int
end

abstract type Constraint end

abstract type ObjectiveFunction end

mutable struct SingleVariableObjective <: ObjectiveFunction
    index::Int # index of the variable
    indices::Vector{Int}
end


# used to designate a feasibility sense
struct NoObjective <: ObjectiveFunction end

mutable struct BasicConstraint <: Constraint
    idx::Int
    fct::Union{MOI.AbstractScalarFunction,MOI.AbstractVectorFunction}
    set::Union{MOI.AbstractScalarSet,MOI.AbstractVectorSet}
    indices::Vector{Int}
    pvals::Vector{Int}
    check_in_best_bound::Bool
    hash::UInt64
end

mutable struct MatchingInit
    l_in_len::Int
    matching_l::Vector{Int}
    matching_r::Vector{Int}
    index_l::Vector{Int}
    process_nodes::Vector{Int}
    depths::Vector{Int}
    parents::Vector{Int}
    used_l::Vector{Bool}
    used_r::Vector{Bool}
end

mutable struct AllDifferentConstraint <: Constraint
    idx::Int
    fct::Union{MOI.AbstractScalarFunction,MOI.AbstractVectorFunction}
    set::Union{MOI.AbstractScalarSet,MOI.AbstractVectorSet}
    indices::Vector{Int}
    pvals::Vector{Int}
    pval_mapping::Vector{Int}
    vertex_mapping::Vector{Int}
    vertex_mapping_bw::Vector{Int}
    di_ei::Vector{Int}
    di_ej::Vector{Int}
    matching_init::MatchingInit
    check_in_best_bound::Bool
    hash::UInt64
end

# support for a <= b constraint
mutable struct SingleVariableConstraint <: Constraint
    idx::Int
    fct::MOI.AbstractScalarFunction
    set::MOI.AbstractScalarSet
    indices::Vector{Int}
    pvals::Vector{Int}
    lhs::Int
    rhs::Int
    check_in_best_bound::Bool
    hash::UInt64
end

struct AllDifferentSet <: MOI.AbstractVectorSet
    dimension::Int
end

struct EqualSet <: MOI.AbstractVectorSet
    dimension::Int
end

struct NotEqualSet{T} <: MOI.AbstractScalarSet
    value::T
end

mutable struct LinearCombination{T<:Real}
    indices::Vector{Int}
    coeffs::Vector{T}
end

mutable struct LinearConstraint{T<:Real} <: Constraint
    idx::Int
    fct::MOI.ScalarAffineFunction
    set::MOI.AbstractScalarSet
    indices::Vector{Int}
    pvals::Vector{Int}
    in_all_different::Bool
    mins::Vector{T}
    maxs::Vector{T}
    pre_mins::Vector{T}
    pre_maxs::Vector{T}
    check_in_best_bound::Bool
    hash::UInt64
end

mutable struct LinearCombinationObjective{T<:Real} <: ObjectiveFunction
    lc::LinearCombination{T}
    constant::T
    indices::Vector{Int} # must exist to update the objective only if one of these changed
end

mutable struct BacktrackObj{T<:Real}
    idx::Int
    parent_idx::Int
    depth::Int
    status::Symbol
    variable_idx::Int
    left_side::Bool # indicates whether we branch left or right: true => ≤ var_bound, false => ≥ var_bound
    var_bound::Int
    best_bound::T
end


function Base.convert(::Type{B}, obj::BacktrackObj{T2}) where {T1,T2,B<:BacktrackObj{T1}}
    return BacktrackObj{T1}(
        obj.idx,
        obj.parent_idx,
        obj.depth,
        obj.status,
        obj.variable_idx,
        obj.left_side,
        obj.var_bound,
        convert(T1, obj.best_bound),
    )
end

mutable struct TreeLogNode{T<:Real}
    id::Int
    status::Symbol
    best_bound::T
    step_nr::Int
    var_idx::Int
    left_side::Bool
    var_bound::Int
    var_states::Dict{Int,Vector{Int}}
    var_changes::Dict{Int,Vector{Tuple{Symbol,Int,Int,Int}}}
    children::Vector{TreeLogNode{T}}
end

mutable struct Solution{T<:Real}
    incumbent::T
    values::Vector{Int}
end

mutable struct ConstraintSolverModel{T<:Real}
    init_search_space::Vector{Variable}
    search_space::Vector{Variable}
    subscription::Vector{Vector{Int}}
    constraints::Vector{Constraint}
    bt_infeasible::Vector{Int}
    c_backtrack_idx::Int
    backtrack_vec::Vector{BacktrackObj{T}}
    sense::MOI.OptimizationSense
    objective::ObjectiveFunction
    best_sol::T # Objective of the best solution
    best_bound::T # Overall best bound
    solutions::Vector{Solution}
    bt_solution_ids::Vector{Int} # saves only the id to the BacktrackObj
    info::CSInfo
    input::Dict{Symbol,Any}
    logs::Vector{TreeLogNode{T}}
    options::SolverOptions
    start_time::Float64
    solve_time::Float64 # seconds spend in solve
end

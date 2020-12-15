# TableLogger

mutable struct TableCol
    id::Symbol
    name::String
    type::DataType
    width::Int
    alignment::Symbol # :left, :center, :right
    b_format::Bool
end

mutable struct TableEntry{T}
    col_id::Symbol
    value::T
end

mutable struct TableSetup
    cols::Vector{TableCol}
    col_idx::Dict{Symbol,Int}
    new_row_criteria::Bool
    diff_criteria::Dict{Symbol,Any}
    last_row::Vector{TableEntry}
end

# SolverOptions
mutable struct ActivityOptions
    decay::Float64
    max_num_probes::Int
    max_confidence_deviation::Float64
end

mutable struct SolverOptions
    logging::Vector{Symbol}
    table::TableSetup
    time_limit::Float64 # time limit in backtracking in seconds
    seed::Int
    traverse_strategy::Symbol
    branch_strategy::Symbol
    branch_split::Symbol # defines splitting in the middle, or takes smallest, biggest value
    backtrack::Bool
    max_bt_steps::Int
    backtrack_sorting::Bool
    keep_logs::Bool
    rtol::Float64
    atol::Float64
    solution_type::Type
    all_solutions::Bool
    all_optimal_solutions::Bool
    lp_optimizer::Any
    no_prune::Bool
    activity::ActivityOptions
    simplify::Bool
end

# General

mutable struct Variable
    idx::Int
    lower_bound::Int # initial lower and
    upper_bound::Int # upper bound of the variable see min, max otherwise
    first_ptr::Int
    last_ptr::Int
    values::Vector{Int}
    indices::Vector{Int}
    init_vals::Vector{Int} # saves all initial values
    init_val_to_index::Vector{Int} # saves the index in which val appears in init_vals
    offset::Int
    min::Int # the minimum value during the solving process
    max::Int # for initial see lower/upper_bound
    # Tuple explanation
    # [1] :fix, :rm, :rm_below, :rm_above
    # [2] To which value got it fixed, which value was removed, which value was the upper/lower bound
    # [3] Only if fixed it saves the last ptr to revert the changes otherwise 0
    # [4] How many values got removed (0 for fix)
    changes::Vector{Vector{Tuple{Symbol,Int,Int,Int}}}
    has_upper_bound::Bool # must be true to work
    has_lower_bound::Bool # must be true to work
    is_fixed::Bool
    is_integer::Bool # must be true to work
    # branching strategies
    activity::Float64 #  + 1 if variable was used in node, * activity.decay if it wasn't
end

mutable struct NumberConstraintTypes
    equality::Int
    inequality::Int
    notequal::Int
    alldifferent::Int
    table::Int
    indicator::Int
    reified::Int
end

mutable struct CSInfo
    pre_backtrack_calls::Int
    backtracked::Bool
    backtrack_fixes::Int
    in_backtrack_calls::Int
    backtrack_reverses::Int
    n_constraint_types::NumberConstraintTypes
end

#====================================================================================
=================== SETS FOR VARIABLES AND CONSTRAINTS ==============================
====================================================================================#

struct Integers <: MOI.AbstractScalarSet
    values::Vector{Int}
end
Integers(vals::Union{UnitRange{Int},StepRange{Int,Int}}) = Integers(collect(vals))
Base.copy(I::Integers) = Integers(I.values)

struct AllDifferentSetInternal <: MOI.AbstractVectorSet
    dimension::Int
end
Base.copy(A::AllDifferentSetInternal) = AllDifferentSetInternal(A.dimension)

struct AllDifferentSet <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AllDifferentSet, dim) = AllDifferentSetInternal(dim)

struct TableSetInternal <: MOI.AbstractVectorSet
    dimension::Int
    table::Array{Int,2}
end
Base.copy(T::TableSetInternal) = TableSetInternal(T.dimension, T.table)

struct TableSet <: JuMP.AbstractVectorSet
    table::Array{Int,2}
end
function JuMP.moi_set(ts::TableSet, dim)
    if size(ts.table,2) != dim
        throw(ArgumentError("The table provided has $(size(ts.table,2)) columns but the variable vector has $dim elements"))
    end
    TableSetInternal(dim, ts.table)
end

struct GeqSetInternal <: MOI.AbstractVectorSet
    dimension::Int
end
Base.copy(G::GeqSetInternal) = GeqSetInternal(G.dimension)

struct GeqSet <: JuMP.AbstractVectorSet end
JuMP.moi_set(::GeqSet, dim) = GeqSetInternal(dim)

struct EqualSetInternal <: MOI.AbstractVectorSet
    dimension::Int
end
Base.copy(E::EqualSetInternal) = EqualSetInternal(E.dimension)

struct EqualSet <: JuMP.AbstractVectorSet end
JuMP.moi_set(::EqualSet, dim) = EqualSetInternal(dim)

struct NotEqualTo{T} <: MOI.AbstractScalarSet
    value::T
end
Base.copy(N::NotEqualTo) = NotEqualTo(N.value)

#====================================================================================
====================== TYPES FOR TRAVERSING ========================================
====================================================================================#

abstract type Priority end

struct PriorityDFS{T<:Real} <: Priority
    depth::Int
    bound::T
    neg_idx::Int # the negative backtrack index (negative because of maximizing)
end

function Base.isless(p1::PriorityDFS, p2::PriorityDFS)
    if p1.depth < p2.depth
        return true
    elseif p1.depth == p2.depth
        if p1.bound < p2.bound
            return true
        elseif p1.bound == p2.bound
            return p1.neg_idx < p2.neg_idx
        else
            return false
        end
    end
    return false
end

struct PriorityBFS{T<:Real} <: Priority
    bound::T
    depth::Int
    neg_idx::Int # the negative backtrack index (negative because of maximizing)
end

function Base.isless(p1::PriorityBFS, p2::PriorityBFS)
    if p1.bound < p2.bound
        return true
    elseif p1.bound == p2.bound
        if p1.depth < p2.depth
            return true
        elseif p1.depth == p2.depth
            return p1.neg_idx < p2.neg_idx
        else
            return false
        end
    end
    return false
end

#====================================================================================
====================== TYPES FOR CONSTRAINTS ========================================
====================================================================================#

abstract type Constraint end

"""
    BoundRhsVariable
idx - variable index in the lp Model
lb  - lower bound of that variable
ub  - upper bound of that variable
"""
mutable struct BoundRhsVariable
    idx::Int
    lb::Int
    ub::Int
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

mutable struct SCCInit
    index_ei::Vector{Int}
    ids::Vector{Int}
    low::Vector{Int}
    on_stack::Vector{Bool}
    group_id::Vector{Int}
end

"""
    RSparseBitSet

See https://arxiv.org/pdf/1604.06641.pdf
words[x] will save 64 possibilities in a TableConstraint a `1` at position y will mean that the
words in row (x-1)*64+y of the table are possible a 0 means that they aren't
Similar to `Variable` a whole block of 64 rows can be removed by changing the `indices` and `last_ptr`.
The `mask` saves the current mask to change words
"""
mutable struct RSparseBitSet
    words::Vector{UInt64}
    indices::Vector{Int}
    last_ptr::Int
    mask::Vector{UInt64}
    RSparseBitSet() = new([], [], 1, [])
end

mutable struct TableSupport
    # defines the range for each variable
    # i.e [1,3,7,10] means that the first variable has 2 values, the second 4
    var_start::Vector{Int}
    values::Array{UInt64,2}
    TableSupport() = new([], Array{UInt64,2}(undef, (0,0)))
end

mutable struct TableResidues
    # defines the range for each variable
    # i.e [1,3,7,10] means that the first variable has 2 values, the second 4
    var_start::Vector{Int}
    values::Vector{Int}
    TableResidues() = new([], [])
end

mutable struct TableBacktrackInfo
    words::Vector{UInt64}
    last_ptr::Int
    indices::Vector{Int}
end

struct IndicatorSet{A} <: MOI.AbstractVectorSet
    func::MOI.VectorOfVariables
    set::MOI.AbstractVectorSet
    dimension::Int
end
Base.copy(I::IndicatorSet{A}) where {A} = IndicatorSet{A}(I.func, I.set, I.dimension)

struct ReifiedSet{A} <: MOI.AbstractVectorSet
    func::Union{JuMP.GenericAffExpr,MOI.VectorOfVariables}
    set::Union{MOI.AbstractScalarSet,MOI.AbstractVectorSet}
    dimension::Int
end
Base.copy(R::ReifiedSet{A}) where {A} = ReifiedSet{A}(R.func, R.set, R.dimension)

#====================================================================================
====================================================================================#

mutable struct ImplementedConstraintFunctions
    init::Bool
    update_init::Bool
    finished_pruning::Bool
    restore_pruning::Bool
    single_reverse_pruning::Bool
    reverse_pruning::Bool
    update_best_bound::Bool
end

mutable struct ConstraintInternals{
    FCT<:Union{MOI.AbstractScalarFunction,MOI.AbstractVectorFunction},
    SET<:Union{MOI.AbstractScalarSet,MOI.AbstractVectorSet},
}
    idx::Int
    fct::FCT
    set::SET
    indices::Vector{Int}
    pvals::Vector{Int}
    impl::ImplementedConstraintFunctions
    is_initialized::Bool
    is_deactivated::Bool # can be deactivated if it's absorbed by other constraints
    bound_rhs::Vector{BoundRhsVariable}# should be set if `update_best_bound` is true
end

#====================================================================================
====================== CONSTRAINTS ==================================================
====================================================================================#

mutable struct BasicConstraint <: Constraint
    std::ConstraintInternals
end

mutable struct EqualConstraint <: Constraint
    std::ConstraintInternals
    first_ptrs::Vector{Int} # for faster apply_changes!
end

mutable struct AllDifferentConstraint <: Constraint
    std::ConstraintInternals
    pval_mapping::Vector{Int}
    vertex_mapping::Vector{Int}
    vertex_mapping_bw::Vector{Int}
    di_ei::Vector{Int}
    di_ej::Vector{Int}
    matching_init::MatchingInit
    scc_init::SCCInit
    # corresponds to `in_all_different`: Saves the constraint idxs where all variables are part of this alldifferent constraint
    sub_constraint_idxs::Vector{Int}
end

# support for a <= b constraint
mutable struct SingleVariableConstraint <: Constraint
    std::ConstraintInternals
    lhs::Int
    rhs::Int
end

mutable struct LinearConstraint{T<:Real} <: Constraint
    std::ConstraintInternals
    in_all_different::Bool
    mins::Vector{T}
    maxs::Vector{T}
    pre_mins::Vector{T}
    pre_maxs::Vector{T}
end

mutable struct TableConstraint <: Constraint
    std::ConstraintInternals
    current::RSparseBitSet
    supports::TableSupport
    last_sizes::Vector{Int}
    residues::TableResidues
    # holds current, last_ptr and indices from each node
    # maybe it's better to compute some of them to save some space...
    # This is the easy implementation first
    backtrack::Vector{TableBacktrackInfo}
    changed_vars::Vector{Int}
    unfixed_vars::Vector{Int}
    sum_min::Vector{Int}
    sum_max::Vector{Int}
end

mutable struct GeqSetConstraint <: Constraint
    std::ConstraintInternals
    vidx::Int
    greater_than::Vector{Int}
    # saves all constraints where all indices are part of the greater_than
    sub_constraint_idxs::Vector{Int}
end

mutable struct IndicatorConstraint{C<:Constraint} <: Constraint
    std::ConstraintInternals
    activate_on::MOI.ActivationCondition
    inner_constraint::C
    indicator_in_inner::Bool # is the indicator variable also in the inner constraint
end

mutable struct ReifiedConstraint{C<:Constraint} <: Constraint
    std::ConstraintInternals
    activate_on::MOI.ActivationCondition
    inner_constraint::C
    reified_in_inner::Bool # is the reified variable also in the inner constraint
end

#====================================================================================
====================== OBJECTIVES ==================================================
====================================================================================#

abstract type ObjectiveFunction end

mutable struct SingleVariableObjective <: ObjectiveFunction
    fct::MOI.SingleVariable
    vidx::Int # index of the variable
    indices::Vector{Int}
end


# used to designate a feasibility sense
struct NoObjective <: ObjectiveFunction end

mutable struct LinearCombination{T<:Real}
    indices::Vector{Int}
    coeffs::Vector{T}
end

mutable struct LinearCombinationObjective{T<:Real} <: ObjectiveFunction
    fct::MOI.ScalarAffineFunction
    lc::LinearCombination{T}
    constant::T
    indices::Vector{Int} # must exist to update the objective only if one of these changed
end

mutable struct BacktrackObj{T<:Real}
    idx::Int
    step_nr::Int
    parent_idx::Int
    depth::Int
    status::Symbol
    vidx::Int
    lb::Int # lb <= var[vidx] <= ub
    ub::Int
    best_bound::T
    primal_start::Vector{Float64}
    solution::Vector{Float64} # holds the solution values of the bound computation
end


function Base.convert(::Type{B}, obj::BacktrackObj{T2}) where {T1,T2,B<:BacktrackObj{T1}}
    return BacktrackObj{T1}(
        obj.idx,
        obj.step_nr,
        obj.parent_idx,
        obj.depth,
        obj.status,
        obj.vidx,
        obj.lb,
        obj.ub,
        convert(T1, obj.best_bound),
        obj.primal_start,
        obj.solution,
    )
end

mutable struct TreeLogNode{T<:Real}
    id::Int
    status::Symbol
    feasible::Bool
    best_bound::T
    step_nr::Int
    vidx::Int
    lb::Int
    ub::Int
    var_states::Dict{Int,Vector{Int}}
    var_changes::Dict{Int,Vector{Tuple{Symbol,Int,Int,Int}}}
    activity::Dict{Int,Float64}
    children::Vector{TreeLogNode{T}}
end

mutable struct Solution{T<:Real}
    incumbent::T
    values::Vector{Int}
    backtrack_id::Int # save where the solution was found
    hash::UInt64
end
Solution(incumbent, values, backtrack_id) =
    Solution(incumbent, values, backtrack_id, hash(values))

mutable struct ActivityObj
    nprobes::Int
    is_free::Vector{Bool}
    ActivityObj() = new(0, [false]) # will be overwritten later
end

"""
    BranchVarObj

Determines the next branch variable and stores if still feasible and if solution was found
"""
mutable struct BranchVarObj
    is_feasible::Bool
    is_solution::Bool
    vidx::Int # only relevant if is_feasible && !is_solution
end

mutable struct ConstraintSolverModel{T<:Real}
    lp_model::Union{Nothing,Model} # only used if lp_optimizer is set
    lp_x::Vector{VariableRef}
    init_search_space::Vector{Variable}
    search_space::Vector{Variable}
    init_fixes::Vector{Tuple{Int,Int}}
    subscription::Vector{Vector{Int}}
    constraints::Vector{Constraint}
    bt_infeasible::Vector{Int}
    c_backtrack_idx::Int
    c_step_nr::Int
    backtrack_vec::Vector{BacktrackObj{T}}
    backtrack_pq::PriorityQueue
    sense::MOI.OptimizationSense
    objective::ObjectiveFunction
    var_in_obj::Vector{Bool} # saves whether a variable is part of the objective function
    traverse_strategy::Val
    branch_strategy::Val
    branch_split::Val
    in_probing_phase::Bool
    activity_vars::ActivityObj
    best_sol::T # Objective of the best solution
    best_bound::T # Overall best bound
    solutions::Vector{Solution}
    info::CSInfo
    input::Dict{Symbol,Any}
    logs::Vector{TreeLogNode{T}}
    options::SolverOptions
    start_time::Float64
    solve_time::Float64 # seconds spend in solve
end
parametric_type(::ConstraintSolverModel{T}) where {T} = T

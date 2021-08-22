function isapprox_discrete(com::CS.CoM, val)
    return isapprox(val, round(val); atol = com.options.atol, rtol = com.options.rtol)
end

function isapprox_divisible(com::CS.CoM, val, divider)
    modulo_near_0 =
        isapprox(val % divider, 0; atol = com.options.atol, rtol = com.options.rtol)
    modulo_near_divider =
        isapprox(val % divider, divider; atol = com.options.atol, rtol = com.options.rtol)
    return modulo_near_0 || modulo_near_divider
end

function get_approx_discrete(val)
    return convert(Int, round(val))
end

function get_safe_upper_threshold(com::CS.CoM, val, divider)
    float_threshold = val / divider
    floor_threshold = floor(float_threshold)
    threshold = convert(Int, floor_threshold)
    # if the difference is almost 1 we round in the other direction to provide a safe upper bound
    if isapprox(
        float_threshold - floor_threshold,
        1.0;
        rtol = com.options.rtol,
        atol = com.options.atol,
    )
        threshold += 1
    end
    return threshold
end

function get_safe_lower_threshold(com::CS.CoM, val, divider)
    float_threshold = val / divider
    ceil_threshold = ceil(float_threshold)
    threshold = convert(Int, ceil_threshold)
    # if the difference is almost 1 we round in the other direction to provide a safe lower bound
    if isapprox(
        ceil_threshold - float_threshold,
        1.0;
        rtol = com.options.rtol,
        atol = com.options.atol,
    )
        threshold -= 1
    end
    return threshold
end

"""
    fixed_vs_unfixed(search_space, indices)

Return the fixed_vals as well as the unfixed_indices
"""
function fixed_vs_unfixed(search_space, indices)
    # get all values which are fixed
    fixed_vals = Int[]
    unfixed_indices = Int[]
    for (i, vidx) in enumerate(indices)
        if isfixed(search_space[vidx])
            push!(fixed_vals, CS.value(search_space[vidx]))
        else
            push!(unfixed_indices, i)
        end
    end
    return (fixed_vals, unfixed_indices)
end

"""
    update_table_log(com::CS.CoM, backtrack_vec; force=false)

Push the new information to the TableLogger and if `force` produce a new line otherwise the TableLogger decides
"""
function update_table_log(com::CS.CoM, backtrack_vec; force = false)
    table = com.options.table
    open_nodes = count(n -> n.status == :Open, backtrack_vec)
    # -1 for dummy node
    closed_nodes = length(backtrack_vec) - open_nodes - 1
    best_bound = com.best_bound
    incumbent = length(com.solutions) == 0 ? "-" : com.best_sol
    duration = time() - com.start_time
    push_to_table!(
        table;
        force = force,
        open_nodes = open_nodes,
        closed_nodes = closed_nodes,
        incumbent = incumbent,
        best_bound = best_bound,
        duration = duration,
    )
end

"""
    arr2dict(arr)

Return a boolean dictionary with keys as the value of the array and `true` if the value exists
"""
function arr2dict(arr)
    d = Dict{Int,Bool}()
    for v in arr
        d[v] = true
    end
    return d
end

function is_constraint_solved_when_fixed(com::CS.CoM, constraint::Constraint, fct, set, vidx::Int, value::Int)
    variables = com.search_space
    !all(isfixed(variables[ind]) || variables[ind].idx == vidx for ind in constraint.indices) && return false
    values = zeros(Int, length(constraint.indices))
    for (i,ind) in enumerate(constraint.indices)
        if ind != vidx
            values[i] = CS.value(variables[ind])
        else
            values[i] = value
        end 
    end
    return is_constraint_solved(com, constraint, values)
end

#=
    Access standard ConstraintInternals without using .std syntax
=#
@inline function Base.getproperty(c::Constraint, s::Symbol)
    if s in (
        :idx,
        :indices,
        :fct,
        :set,
        :first_node_call,
        :vidx_to_idx,
        :pvals,
        :is_initialized,
        :is_activated,
        :is_deactivated,
        :bound_rhs,
    )
        Core.getproperty(Core.getproperty(c, :std), s)
    else
        getfield(c, s)
    end
end

@inline function Base.setproperty!(c::Constraint, s::Symbol, v)
    if s in (
        :idx,
        :indices,
        :fct,
        :set,
        :first_node_call,
        :vidx_to_idx,
        :pvals,
        :is_initialized,
        :is_activated,
        :is_deactivated,
        :bound_rhs,
    )
        Core.setproperty!(c.std, s, v)
    else
        Core.setproperty!(c, s, v)
    end
end

#=
    Access standard ActivatorConstraintInternals without using .act_std syntax
=#
@inline function Base.getproperty(c::ActivatorConstraint, s::Symbol)
    if s in (
        :idx,
        :indices,
        :fct,
        :set,
        :first_node_call,
        :vidx_to_idx,
        :pvals,
        :is_initialized,
        :is_activated,
        :is_deactivated,
        :bound_rhs,
    )
        Core.getproperty(Core.getproperty(c, :std), s)
    elseif s in (
        :activate_on,
        :activator_in_inner,
        :inner_activated,
        :inner_activated_in_backtrack_idx,
    )
        Core.getproperty(Core.getproperty(c, :act_std), s)
    else
        getfield(c, s)
    end
end

@inline function Base.setproperty!(c::ActivatorConstraint, s::Symbol, v)
    if s in (
        :idx,
        :indices,
        :fct,
        :set,
        :first_node_call,
        :vidx_to_idx,
        :pvals,
        :is_initialized,
        :is_activated,
        :is_deactivated,
        :bound_rhs,
    )
        Core.setproperty!(c.std, s, v)
    elseif s in (
        :activate_on,
        :activator_in_inner,
        :inner_activated,
        :inner_activated_in_backtrack_idx,
    )
        Core.setproperty!(c.act_std, s, v)
    else
        Core.setproperty!(c, s, v)
    end
end

#=
    Access standard BoolConstraintInternals without using .bool_std syntax
=#
@inline function Base.getproperty(c::BoolConstraint, s::Symbol)
    if s in (
        :idx,
        :indices,
        :fct,
        :set,
        :first_node_call,
        :vidx_to_idx,
        :pvals,
        :is_initialized,
        :is_activated,
        :is_deactivated,
        :bound_rhs,
    )
        Core.getproperty(Core.getproperty(c, :std), s)
    elseif s in (
        :lhs_activated,
        :lhs_activated_in_backtrack_idx,
        :rhs_activated,
        :rhs_activated_in_backtrack_idx,
        :lhs,
        :rhs
    )
        Core.getproperty(Core.getproperty(c, :bool_std), s)
    else
        getfield(c, s)
    end
end

@inline function Base.setproperty!(c::BoolConstraint, s::Symbol, v)
    if s in (
        :idx,
        :indices,
        :fct,
        :set,
        :first_node_call,
        :vidx_to_idx,
        :pvals,
        :is_initialized,
        :is_activated,
        :is_deactivated,
        :bound_rhs,
    )
        Core.setproperty!(c.std, s, v)
    elseif s in (
        :lhs_activated,
        :lhs_activated_in_backtrack_idx,
        :rhs_activated,
        :rhs_activated_in_backtrack_idx,
        :lhs,
        :rhs
    )
        Core.setproperty!(c.bool_std, s, v)
    else
        Core.setproperty!(c, s, v)
    end
end

@inline function Base.getproperty(c::AbstractBoolSet, s::Symbol)
    if s in (
        :lhs_set,
        :rhs_set,
        :lhs_dimension,
        :rhs_dimension,
        :dimension,
    )
        Core.getproperty(Core.getproperty(c, :bsi), s)
    else
        getfield(c, s)
    end
end


"""
    Return whether the given LinearConstraint doesn't contain any variables i.e for 0 <= 0
"""
function is_no_variable_constraint(constraint::LinearConstraint)
    return length(constraint.indices) == 0
end

get_value(::Type{Val{i}}) where i = i

for bool_pair = BOOL_SET_TO_CONSTRAINT
    bool_set = bool_pair.first
    @eval typeof_without_params(::$bool_set) = $bool_set
    @eval typeof_without_params(::Type{<:$bool_set}) = $bool_set
end

function get_constraint(com, fct, set)
    if fct isa SAF
        return get_linear_constraint(fct, set)
    else
        internals = create_internals(fct, set)
        return init_constraint_struct(com, set, internals) 
    end
end

get_saf(fct::MOI.ScalarAffineFunction) = fct
get_saf(fct::MOI.VectorAffineFunction) = MOI.ScalarAffineFunction([t.scalar_term for t in fct.terms], fct.constants[1])

get_vov(fct::MOI.VectorOfVariables) = fct
get_vov(fct::MOI.VectorAffineFunction) = MOI.VectorOfVariables([t.scalar_term.variable_index for t in fct.terms])

"""
    init_and_activate_constraint!(com, constraint, fct, set)

Initializes and activates the constraint. Does **not** check whether the functions are implemented.
"""
function init_and_activate_constraint!(
    com::CS.CoM,
    constraint::Constraint,
    fct,
    set
)
    !init_constraint!(com, constraint, fct, set) && return false
    constraint.is_initialized = true
    !activate_constraint!(com, constraint, fct, set) && return false
    constraint.is_activated = true
    return true
end

"""
    push_to_changes!(v::Variable, tuple::Tuple{Symbol,Int,Int,Int})   

Push a new change to the variable `v`. 
"""
function push_to_changes!(v::Variable, tuple::Tuple{Symbol,Int,Int,Int})
    v.changes.indices[end] += 1
    push!(v.changes.changes, tuple)
    @assert v.changes.indices[end]-1 == length(v.changes.changes)
end

"""
    num_changes(v::Variable, step_nr::Int)

Return the number of changes that were done for `v` in `step_nr`.
"""
function num_changes(v::Variable, step_nr::Int)
    return v.changes.indices[step_nr+1] - v.changes.indices[step_nr]
end

"""
    view_changes(v::Variable, step_nr::Int) 

Return a view of the changes made for `v` in `step_nr`
"""
function view_changes(v::Variable, step_nr::Int)
    idx_begin = v.changes.indices[step_nr]
    idx_end = v.changes.indices[step_nr+1]-1
    return @views v.changes.changes[idx_begin:idx_end]
end

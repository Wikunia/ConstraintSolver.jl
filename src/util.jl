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

function is_constraint_solved(com::CS.CoM, constraint::Constraint, fct, set)
    variables = com.search_space
    !all(isfixed(variables[var]) for var in constraint.indices) && return false
    values = CS.value.(variables[constraint.indices])
    return is_constraint_solved(constraint, fct, set, values)
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
        :pvals,
        :impl,
        :is_initialized,
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
        :pvals,
        :impl,
        :is_initialized,
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
        :pvals,
        :impl,
        :is_initialized,
        :is_deactivated,
        :bound_rhs,
    )
        Core.getproperty(Core.getproperty(c, :std), s)
    elseif s in (
        :activate_on,
        :activator_in_inner,
        :inner_activated,
        :sactivated_in_backtrack_idxet,
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
        :pvals,
        :impl,
        :is_initialized,
        :is_deactivated,
        :bound_rhs,
    )
        Core.setproperty!(c.std, s, v)
    elseif s in (
        :activate_on,
        :activator_in_inner,
        :inner_activated,
        :activated_in_backtrack_idx,
    )
        Core.setproperty!(c.act_std, s, v)
    else
        Core.setproperty!(c, s, v)
    end
end



"""
    Return whether the given LinearConstraint doesn't contain any variables i.e for 0 <= 0
"""
function is_no_variable_constraint(constraint::LinearConstraint)
    return length(constraint.indices) == 0
end

get_value(::Type{Val{i}}) where i = i

function typeof_without_parmas(::AndSet)
    return AndSet
end

function typeof_without_parmas(::OrSet)
    return OrSet
end

function get_constraint(fct, set)
    if fct isa SAF
        return new_linear_constraint(fct, set)
    else
        internals = create_interals(fct, set)
        return init_constraint_struct(set, internals) 
    end
end

function get_saf(fct::MOI.VectorAffineFunction)
    MOI.ScalarAffineFunction([t.scalar_term for t in fct.terms], fct.constants[1])
end

function get_vov(fct::MOI.VectorAffineFunction)
    return MOI.VectorOfVariables([t.scalar_term.variable_index for t in fct.terms])
end
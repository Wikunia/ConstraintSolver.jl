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
    var_vector_to_moi(vars::Vector{Variable})

Convert a vector of variables to MOI.VectorOfVariables
"""
function var_vector_to_moi(vars::Vector{Variable})
    return MOI.VectorOfVariables([MOI.VariableIndex(v.idx) for v in vars])
end

"""
    linear_combination_to_saf(lc::LinearCombination)

Convert a LinearCombination to a ScalarAffineFunction and return the SAF + the used type
"""
function linear_combination_to_saf(lc::LinearCombination)
    T = eltype(lc.coeffs)
    sat = [
        MOI.ScalarAffineTerm{T}(lc.coeffs[i], MOI.VariableIndex(lc.indices[i]))
        for i = 1:length(lc.indices)
    ]
    return SAF{T}(sat, zero(T)), T
end

"""
    fixed_vs_unfixed(search_space, indices)

Return the fixed_vals as well as the unfixed_indices
"""
function fixed_vs_unfixed(search_space, indices)
    # get all values which are fixed
    fixed_vals = Int[]
    unfixed_indices = Int[]
    for (i, ind) in enumerate(indices)
        if isfixed(search_space[ind])
            push!(fixed_vals, CS.value(search_space[ind]))
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
    incumbent = length(com.bt_solution_ids) == 0 ? "-" : com.best_sol
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

function is_solved_constraint(com::CS.CoM, constraint::Constraint, fct, set)
    variables = com.search_space
    !all(isfixed(variables[var]) for var in constraint.std.indices) && return false
    values = CS.value.(variables[constraint.std.indices])
    return is_solved_constraint(constraint, fct, set, values)
end
"""
    Base.:(<=)(x::LinearCombination, y::Real)

Create a linear constraint with `LinearCombination` and an integer rhs `y`. \n
Can be used i.e by `add_constraint!(com, x+y <= 2)`.
"""
function Base.:(<=)(x::LinearCombination, y::Real)
    indices, coeffs, constant_lhs = simplify(x)
    
    rhs = y-constant_lhs
    func, T = linear_combination_to_saf(LinearCombination(indices, coeffs))
    lc = LinearConstraint(func, MOI.LessThan{T}(rhs), indices)
    
    lc.hash = constraint_hash(lc)
    return lc
end

function Base.:(<=)(x::Real, y::LinearCombination)
    return -y <= -x
end

"""
    Base.:(<=)(x::LinearCombination, y::Variable)

Create a linear constraint with `LinearCombination` and a variable rhs `y`. \n
Can be used i.e by `add_constraint!(com, x+y <= z)`.
"""
function Base.:(<=)(x::LinearCombination, y::Variable)
    return x - LinearCombination([y.idx], [1]) <= 0
end

"""
    Base.:(<=)(x::Variable, y::LinearCombination)

Create a linear constraint with a variable `x` and a `LinearCombination` rhs `y`. \n
Can be used i.e by `add_constraint!(com, x <= y+z)`.
"""
function Base.:(<=)(x::Variable, y::LinearCombination)
    return LinearCombination([x.idx], [1]) - y <= 0
end

"""
    Base.:(<=)(x::LinearCombination, y::LinearCombination)

Create a linear constraint with `LinearCombination` on the left and right hand side. \n
Can be used i.e by `add_constraint!(com, x+y <= a+b)`.
"""
function Base.:(<=)(x::LinearCombination, y::LinearCombination)
    return x-y <= 0
end

"""
    get_constrained_best_bound(com::CS.CoM, constraint::LinearConstraint, con_fct::SAF{T}, set::MOI.LessThan{T}, obj_fct::LinearCombinationObjective, var_idx, val)  where T <: Real

Using the greedy knapsack method for obtaining a best bound given this constraint. 
Returns the best bound
"""
function get_constrained_best_bound(com::CS.CoM, constraint::LinearConstraint, con_fct::SAF{T}, set::MOI.LessThan{T}, obj_fct::LinearCombinationObjective, var_idx::Int, val::Int)  where T <: Real
    capacity = set.upper
    costs = [t.coefficient for t in con_fct.terms]
    
    # only check if it is a <= constraint with positive coefficients
    if capacity < 0 && all(c->c < 0, costs) && com.sense == MOI.MAX_SENSE
        return typemax(T)
    end
    if capacity > 0 && all(c->c > 0, costs) && com.sense == MOI.MIN_SENSE
        return typemin(T)
    end
    
    gains = obj_fct.lc.coeffs
    if com.sense == MOI.MIN_SENSE
        gains = -gains
    end

    cost_indices = [t.variable_index.value for t in con_fct.terms]
    gain_indices = obj_fct.lc.indices

    # line up the indices such that only the indices that exist in both are considered
    cost_sort_order = sortperm(cost_indices)
    gain_sort_order = sortperm(gain_indices)

    cost_indices_sorted = cost_indices[cost_sort_order]
    gain_indices_sorted = gain_indices[gain_sort_order]
    # println("cost_indices_sorted: $cost_indices_sorted")
    # println("gain_indices_sorted: $gain_indices_sorted")

    costs_sorted = costs[cost_sort_order]
    gains_sorted = gains[gain_sort_order]

    gain_i = 1
    cost_i = 1

    add_gain_local_indices = Int[]
    relevant_costs = Vector{T}()
    relevant_gains = Vector{T}()
    relevant_indices = Int[]

    while cost_i <= length(cost_indices_sorted) && gain_i <= length(gain_indices_sorted)
        if cost_indices_sorted[cost_i] == gain_indices_sorted[gain_i]
            push!(relevant_costs, costs_sorted[cost_i])
            push!(relevant_gains, gains_sorted[gain_i])
            push!(relevant_indices, gain_i)
            cost_i += 1
            gain_i += 1
        elseif cost_indices_sorted[cost_i] < gain_indices_sorted[gain_i]
            cost_i += 1
        else
            push!(add_gain_local_indices, gain_i)
            gain_i += 1
        end
    end

    # only check if it is a <= constraint with positive coefficients for the relevant costs
    if capacity < 0 && all(c->c < 0, relevant_costs) && com.sense == MOI.MAX_SENSE
        return typemax(T)
    end
    if capacity > 0 && all(c->c > 0, relevant_costs) && com.sense == MOI.MIN_SENSE
        return typemin(T)
    end

    # all costs and the capacity > 0 
    best_bound = zero(T)

    for i=gain_i:length(gain_indices_sorted)
        push!(add_gain_local_indices, gain_i)
    end

    # add unbounded variables directly  
    var_in_relevant = true
    for i=1:length(add_gain_local_indices)
        local_idx = add_gain_local_indices[i]
        v_idx = gain_indices_sorted[local_idx]
        if v_idx == var_idx
            best_bound += gains_sorted[local_idx]*val
            var_in_relevant = false
        else
            # we always have a maximization problem now
            if gains_sorted[local_idx] >= 0
                best_bound += gains_sorted[local_idx]*com.search_space[v_idx].max
            else
                best_bound += gains_sorted[local_idx]*com.search_space[v_idx].min
            end
        end
    end

    # println("com.search_space: $(com.search_space)")
    # println("best_bound before knapsack calculation: $best_bound")

    # println("capacity: $capacity")
    # println("add_gain_local_indices: $add_gain_local_indices")
    # println("relevant_costs: $relevant_costs")
    # println("relevant_gains: $relevant_gains")

    # order by gain per cost desc  
    gain_per_cost = relevant_gains ./ relevant_costs
    gain_per_cost_perm = sortperm(gain_per_cost; rev=true)
    relevant_costs_sorted = relevant_costs[gain_per_cost_perm]
    gain_per_cost_sorted = relevant_gains[gain_per_cost_perm]
    relevant_indices_sorted = relevant_indices[gain_per_cost_perm]

    # println("var_idx: $var_idx")
    # println("val: $val")

    if var_in_relevant
        for i=1:length(relevant_indices_sorted)
            v_idx = relevant_indices_sorted[i]
            if v_idx == var_idx
                best_bound += val*gain_per_cost_sorted[i]
                capacity -= val*relevant_costs_sorted[i]
                break
            end
        end
    end

    i = 1
    while capacity > 0 && i <= length(relevant_indices_sorted)
        v_idx = relevant_indices_sorted[i]
        # already added
        if v_idx == var_idx
            i += 1
            continue
        end
        load_number = min(capacity/relevant_costs_sorted[i], com.search_space[v_idx].max)
        # println("$load_number from $v_idx")
        capacity -= load_number*relevant_costs_sorted[i]
        best_bound += load_number*gain_per_cost_sorted[i]
        i += 1
    end

    # println("best_bound after knapsack calculation: $best_bound")
    if com.sense == MOI.MIN_SENSE
        return -best_bound
    end
    return best_bound
end

function prune_constraint!(com::CS.CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.LessThan{T}; logs = true) where T <: Real
    indices = constraint.indices
    search_space = com.search_space
    rhs = set.upper - fct.constant

    # compute max and min values for each index
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins
    for (i,idx) in enumerate(indices)
        if fct.terms[i].coefficient >= 0
            max_val = search_space[idx].max * fct.terms[i].coefficient
            min_val = search_space[idx].min * fct.terms[i].coefficient
        else
            min_val = search_space[idx].max * fct.terms[i].coefficient
            max_val = search_space[idx].min * fct.terms[i].coefficient
        end
        maxs[i] = max_val
        mins[i] = min_val
        pre_maxs[i] = max_val
        pre_mins[i] = min_val
    end

    # for each index compute the minimum value possible
    # to fulfill the constraint
    full_min = sum(mins)-rhs

    # if the minimum is bigger than 0 (and not even near zero)
    # the equation can't sum to <= 0 => infeasible
    if full_min > com.options.atol
        com.bt_infeasible[indices] .+= 1
        return false
    end

    for (i,idx) in enumerate(indices)
        if isfixed(search_space[idx])
            continue
        end
        # minimum without current index
        c_min = full_min-mins[i]
        # if the current maximum is too high set a new maximum value to be less than 0
        if c_min + maxs[i] > com.options.atol
            maxs[i] = -c_min
        end
    end

    # update all
    for (i,idx) in enumerate(indices)
        # if the maximum of coefficient * variable got reduced
        # get a safe threshold because of floating point errors
        if maxs[i] < pre_maxs[i]
            threshold = get_safe_upper_threshold(com, maxs[i], fct.terms[i].coefficient)
            if fct.terms[i].coefficient > 0
                still_feasible = remove_above!(com, search_space[idx], threshold)
            else
                still_feasible = remove_below!(com, search_space[idx], threshold)
            end
            if !still_feasible
                return false
            end
        end
    end

    return true
end

function still_feasible(com::CoM, constraint::LinearConstraint, fct::SAF{T}, set::MOI.LessThan{T}, val::Int, index::Int) where T <: Real
    search_space = com.search_space
    rhs = set.upper - fct.constant
    min_sum = zero(T)

    for (i,idx) in enumerate(constraint.indices)
        if idx == index
            min_sum += val*fct.terms[i].coefficient
            continue
        end
        if isfixed(search_space[idx])
            min_sum += CS.value(search_space[idx])*fct.terms[i].coefficient
        else
            if fct.terms[i].coefficient >= 0
                min_sum += search_space[idx].min*fct.terms[i].coefficient
            else
                min_sum += search_space[idx].max*fct.terms[i].coefficient
            end
        end
    end
    if min_sum > rhs+com.options.atol
        return false
    end

    return true
end

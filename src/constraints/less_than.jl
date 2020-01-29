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

mutable struct ArrayDiff
    only_left_idx    :: Vector{Int} # which indices are only left
    same_left_idx    :: Vector{Int} # in both indicating the position in left
    same_right_idx   :: Vector{Int} # in both indicating the position in left
    only_right_idx   :: Vector{Int} # only right
end

"""
    get_idx_array_diff(left::Vector{Int}, right::Vector{Int})

Given two vectors of indices the indices are computed which are only left/right or in both.
The result is of type `ArrayDiff` and holds the local indices pointing to the position in the given vectors.

i.e `get_idx_array_diff([3,5,7], [7,5,2,9])` results in:

```
ArrayDiff(
    [1], [2,3], [2,1], [3,4]
)
```
"""
function get_idx_array_diff(left::Vector{Int}, right::Vector{Int})
    left_perm = sortperm(left)
    right_perm = sortperm(right)
    left_sorted = left[left_perm]
    right_sorted = right[right_perm]

    li = 1
    ri = 1
    ln = length(left)
    rn = length(right)

    ad_left_idx = Int[]
    ad_right_idx = Int[]
    ad_same_left_idx = Int[]
    ad_same_right_idx = Int[]

    while li <= ln && ri <= rn
        if left_sorted[li] == right_sorted[ri]
            push!(ad_same_left_idx, left_perm[li])
            push!(ad_same_right_idx, right_perm[ri])
            li += 1
            ri += 1
        elseif left_sorted[li] < right_sorted[ri]
            push!(ad_left_idx, left_perm[li])
            li += 1
        else
            push!(ad_right_idx, right_perm[ri])
            ri += 1
        end
    end

    for i=li:ln
        push!(ad_left_idx, left_perm[i])
    end
    for i=ri:rn
        push!(ad_right_idx, right_perm[i])
    end
    return ArrayDiff(ad_left_idx, ad_same_left_idx, ad_same_right_idx, ad_right_idx)
end

"""
    get_constrained_best_bound(com::CS.CoM, constraint::LinearConstraint, con_fct::SAF{T}, set::MOI.LessThan{T}, obj_fct::LinearCombinationObjective, var_idx, val)  where T <: Real

Using the greedy knapsack method for obtaining a best bound given this constraint. 
Returns the best bound
"""
function get_constrained_best_bound(com::CS.CoM, constraint::LinearConstraint, con_fct::SAF{T}, set::MOI.LessThan{T}, obj_fct::LinearCombinationObjective, var_idx::Int, val::Int; log=false)  where T <: Real
    capacity = set.upper
    costs = [t.coefficient for t in con_fct.terms]
    
    # only check if it is a <= constraint with at least one positive coefficient
    if capacity < 0 && all(c->c < 0, costs) && com.sense == MOI.MAX_SENSE
        return typemax(T)
    end
    # or return the minimum if the opposite happens in the minimize case
    if capacity > 0 && all(c->c > 0, costs) && com.sense == MOI.MIN_SENSE
        return typemin(T)
    end
    
    gains = obj_fct.lc.coeffs
    cost_indices = [t.variable_index.value for t in con_fct.terms]
    gain_indices = obj_fct.lc.indices

    ad = get_idx_array_diff(cost_indices, gain_indices)
    log && println("ad: $ad")

    relevant_costs = costs[ad.same_left_idx]

    # only check if it is a <= constraint with positive coefficients for the relevant costs
    if capacity < 0 && all(c->c < 0, relevant_costs) && com.sense == MOI.MAX_SENSE
        return typemax(T)
    end
    if capacity > 0 && all(c->c > 0, relevant_costs) && com.sense == MOI.MIN_SENSE
        return typemin(T)
    end



    # best bound starts with constant term
    best_bound = obj_fct.constant

    # if we want to minimize we want to have a look at >= constraints
    # => costs = -costs and capacity = -capacity and renaming to be sure that we don't mess it up
    log && println("Gains: $gains")
    if com.sense == MOI.MIN_SENSE
        anti_costs = -costs
        threshold = -capacity
        log && println("AntiCosts: $anti_costs")
        log && println("Threshold: $threshold")
    else
        log && println("Costs: $costs")
        log && println("Capacity: $capacity")
    end


    # 1) Updating threshold by looking at entries which are only in costs (not changing the best bound)
    if com.sense == MOI.MIN_SENSE
        # trying to maximize the anti_costs to get over the threshold
        for ci in ad.only_left_idx
            if anti_costs[ci] >= 0
                threshold -= anti_costs[ci]*com.search_space[cost_indices[ci]].max
            else
                threshold -= anti_costs[ci]*com.search_space[cost_indices[ci]].min
            end
        end
        log && println("Threshold after 1): ", threshold)
    else
        # trying to minimize the costs to have a lot of capacity left
        for ci in ad.only_left_idx
            if costs[ci] >= 0
                capacity -= costs[ci]*com.search_space[cost_indices[ci]].min
            else
                capacity -= costs[ci]*com.search_space[cost_indices[ci]].max
            end
        end
        log && println("Capacity after 1): ", capacity)
    end

    log && println("Best bound before 2): $best_bound")

    # 2) Optimize packing where the index is both in the cost function as well as in the objective
    if com.sense == MOI.MIN_SENSE
        anti_cost_per_gain = anti_costs[ad.same_left_idx]./gains[ad.same_right_idx]
        # indices where gains is negative and anti_cost_per_gain as well
        # are best so they have a gain in our ordering of Inf
        for i=1:length(anti_cost_per_gain)
            if anti_cost_per_gain[i] < 0 && gains[ad.same_right_idx][i] < 0
                anti_cost_per_gain[i] = typemax(T)
            end
        end
        
        ordering = sortperm(anti_cost_per_gain; rev=true)

        gains_ordered = gains[ad.same_right_idx][ordering]
        anti_costs_ordered = anti_costs[ad.same_left_idx][ordering]
        vars_ordered = cost_indices[ad.same_left_idx][ordering]
        for i=1:length(ad.same_left_idx)
            anti_cost = anti_costs_ordered[i]
            gain = gains_ordered[i]
            v_idx = vars_ordered[i]
            log && println("v_idx: $v_idx")
            log && println("gain: $gain")
            log && println("anti_cost: $anti_cost")
            log && println("threshold: $threshold")
            if  gain < 0 && anti_cost > 0
                if gain >= 0
                    amount = com.search_space[v_idx].min
                else 
                    amount = com.search_space[v_idx].max
                end
            else
                amount = min(threshold/anti_cost, com.search_space[v_idx].max) 
            end
            log && println("amount: $amount")
            log && println("---------------")
            threshold -= amount*anti_cost
            best_bound += amount*gain
            threshold <= com.options.atol && break
        end
    else
        gain_per_cost = gains[ad.same_right_idx]./costs[ad.same_left_idx]
        ordering = sortperm(gain_per_cost; rev=true)

        gains_ordered = gains[ad.same_right_idx][ordering]
        costs_ordered = costs[ad.same_left_idx][ordering]
        vars_ordered = cost_indices[ad.same_left_idx][ordering]

        for i=1:length(ad.same_left_idx)
            cost = costs_ordered[i]
            gain = gains_ordered[i]
            v_idx = vars_ordered[i]
            amount = min(capacity/cost, com.search_space[v_idx].max) 
            amount = max(amount, com.search_space[v_idx].min) 
            capacity -= amount*cost
            best_bound += amount*gain
            capacity <= com.options.atol && break
        end
    end
    log && println("Best bound after 2): $best_bound")
    
    # 3) Use the variables which have no cost but only gains
    if com.sense == MOI.MIN_SENSE
        # trying to minimize the additions to the best bound
        for ci in ad.only_right_idx
            if gains[ci] >= 0
                best_bound += gains[ci]*com.search_space[gain_indices[ci]].min
            else
                best_bound += gains[ci]*com.search_space[gain_indices[ci]].max
            end
        end
    else
        # trying to maximize the additions to the best bound
        for ci=1:length(ad.only_right_idx)
            if gains[ci] >= 0
                best_bound += gains[ci]*com.search_space[gain_indices[ci]].max
            else
                best_bound += gains[ci]*com.search_space[gain_indices[ci]].min
            end
        end
    end

    log && println("best_bound after knapsack calculation: $best_bound")
    log && println("-------------------------------------")
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

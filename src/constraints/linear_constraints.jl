"""
    Get the rhs for a strictly less than set such that it cna be used as a <= constraint.

"""
function get_rhs_from_strictly(com::CS.CoM, constraint::LinearConstraint,
        fct, set::CPE.Strictly{MOI.LessThan{T}, T}) where {T<:Real}

    constraint.is_rhs_strong && return constraint.rhs

    constraint.is_rhs_strong = true
    constraint.rhs = set.set.upper - fct.constant

    # change the rhs in such a way that <= can be used
    # if all coefficients are 1 or -1
    if all(abs(term.coefficient) == 1 for term in fct.terms)
        # => just subtract one from the rhs if rhs is discrete
        if isapprox_discrete(com, constraint.rhs)
            return constraint.rhs - 1
        else # otherwise round down so 9.5 => 9
            return floor(constraint.rhs)
        end
    else
        # use lp solver if it exists and if it supports MIP
        fallback_rhs = constraint.rhs - com.options.atol
        com.options.lp_optimizer === nothing && return fallback_rhs

        if !MOI.supports_constraint(
            com.options.lp_optimizer.optimizer_constructor(),
            SVF, MOI.Integer
        ) || !MOI.supports_constraint(
            com.options.lp_optimizer.optimizer_constructor(),
            typeof(constraint.fct),
            typeof(constraint.set.set),
        ) || !MOI.supports(com.options.lp_optimizer.optimizer_constructor(),
              MOI.ObjectiveFunction{typeof(constraint.fct)}()
        ) || !MOI.supports(com.options.lp_optimizer.optimizer_constructor(), MOI.ObjectiveSense())
            return fallback_rhs
        end

        # supports MIP and <=
        mip_model = Model()
        mip_backend = backend(mip_model)

        set_optimizer(mip_model, com.options.lp_optimizer)
        lp_x = Vector{VariableRef}(undef, length(com.search_space))
        for variable in com.search_space
            lp_x[variable.idx] = @variable(
                mip_model,
                lower_bound = variable.lower_bound,
                upper_bound = variable.upper_bound,
                integer = true
            )
        end
        MOI.add_constraint(mip_backend, constraint.fct, typeof(constraint.set.set)(set.set.upper - com.options.atol))
        MOI.set(mip_backend, MOI.ObjectiveFunction{typeof(constraint.fct)}(), constraint.fct)
        MOI.set(mip_backend, MOI.ObjectiveSense(), MOI.MAX_SENSE)
        optimize!(mip_model)

        if termination_status(mip_model) == MOI.OPTIMAL
            return objective_value(mip_model)
        else
            # TODO: return that it's not feasible
            return fallback_rhs
        end
    end
end

"""
    init_constraint!(com::CS.CoM, constraint::CS.LinearConstraint,fct::SAF{T}, set::CPE.Strictly{MOI.LessThan{T}})

Initialize the LinearConstraint by checking whether it might be an unfillable constraint
without variable i.e x == x-1 => x -x == -1 => 0 == -1 => return false
"""
function init_constraint!(
    com::CS.CoM,
    constraint::CS.LinearConstraint,
    fct::SAF{T},
    set::CPE.Strictly{MOI.LessThan{T}};
) where {T<:Real}
    # rhs will be changed to use as <=
    constraint.rhs = get_rhs_from_strictly(com, constraint, fct, set)
    constraint.strict_rhs = set.set.upper - fct.constant
    constraint.is_strict = true
    is_no_variable_constraint(constraint) && return fct.constant < set.set.upper
    recompute_lc_extrema!(com, constraint, fct)
    return true
end

"""
    init_constraint!(com::CS.CoM, constraint::CS.LinearConstraint,fct::SAF{T}, set::MOI.LessThan{T})

Initialize the LinearConstraint by checking whether it might be an unfillable constraint
without variable i.e x == x-1 => x -x == -1 => 0 == -1 => return false
"""
function init_constraint!(
    com::CS.CoM,
    constraint::CS.LinearConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T};
) where {T<:Real}
    constraint.rhs = set.upper - fct.constant
    is_no_variable_constraint(constraint) && return fct.constant <= set.upper
    recompute_lc_extrema!(com, constraint, fct)
    return true
end

function init_constraint!(
    com::CS.CoM,
    constraint::CS.LinearConstraint,
    fct::SAF{T},
    set::MOI.EqualTo{T};
) where {T<:Real}
    constraint.rhs = set.value - fct.constant
    is_no_variable_constraint(constraint) && return fct.constant == set.value
    recompute_lc_extrema!(com, constraint, fct)
    return true
end

function changed!(com::CS.CoM, constraint::LinearConstraint, fct, set)
    recompute_lc_extrema!(com, constraint, fct)
end

"""
    get_new_extrema_and_sum(search_space, vidx, i, terms, full_min, full_max, pre_mins, pre_maxs)

Get the updated full_min, full_max as well as updated pre_mins[i] and pre_maxs[i]
after values got removed from search_space[vidx]
Return full_min, full_max, pre_mins[i], pre_maxs[i]
"""
function get_new_extrema_and_sum(
    search_space,
    vidx,
    i,
    terms,
    full_min,
    full_max,
    pre_mins,
    pre_maxs,
)
    new_min = pre_mins[i]
    new_max = pre_maxs[i]
    if terms[i].coefficient > 0
        coeff_min = search_space[vidx].min * terms[i].coefficient
        coeff_max = search_space[vidx].max * terms[i].coefficient
        full_max -= (coeff_max - pre_maxs[i])
        full_min += (coeff_min - pre_mins[i])
        new_min = coeff_min
        new_max = coeff_max
    else
        coeff_min = search_space[vidx].max * terms[i].coefficient
        coeff_max = search_space[vidx].min * terms[i].coefficient
        full_max -= (coeff_max - pre_maxs[i])
        full_min += (coeff_min - pre_mins[i])
        new_min = coeff_min
        new_max = coeff_max
    end
    return full_min, full_max, new_min, new_max
end

function recompute_lc_extrema!(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
) where {T<:Real}
    indices = constraint.indices
    search_space = com.search_space
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins

    for (i, vidx) in enumerate(indices)
        if fct.terms[i].coefficient >= 0
            max_val = search_space[vidx].max * fct.terms[i].coefficient
            min_val = search_space[vidx].min * fct.terms[i].coefficient
        else
            min_val = search_space[vidx].max * fct.terms[i].coefficient
            max_val = search_space[vidx].min * fct.terms[i].coefficient
        end
        maxs[i] = max_val
        mins[i] = min_val
        pre_maxs[i] = max_val
        pre_mins[i] = min_val
    end
end

"""
    get_fixed_rhs(com::CS.CoM, constraint::Constraint)

Compute the fixed rhs based on all already fixed variables
"""
function get_fixed_rhs(com::CS.CoM, constraint::Constraint)
    rhs = constraint.rhs
    fct = constraint.fct
    search_space = com.search_space
    @inbounds for li in 1:length(constraint.indices)
        vidx = constraint.indices[li]
        var = search_space[vidx]
        !isfixed(var) && continue
        rhs -= CS.value(var) * fct.terms[li].coefficient
    end
    return rhs
end

"""
    set_new_extrema(i, pre_mins, pre_maxs, new_min, new_max)

Update pre_mins and pre_maxs if new_min or new_max is smaller or bigger.
Return wheter a value was updated
"""
function set_new_extrema(i, pre_mins, pre_maxs, new_min, new_max)
    changed = false
    if new_min != pre_mins[i]
        changed = true
        pre_mins[i] = new_min
    end
    if new_max != pre_maxs[i]
        changed = true
        pre_maxs[i] = new_max
    end
    return changed
end

"""
    prune_constraint!(com::CS.CoM, constraint::LinearConstraint, fct::SAF{T}, set; logs = true) where T <: Real

Reduce the number of possibilities given the equality `LinearConstraint` .
Return if still feasible and throw a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::Union{MOI.LessThan, MOI.EqualTo, CPE.Strictly{MOI.LessThan{T}}};
    logs = true,
) where {T<:Real}
    indices = constraint.indices
    search_space = com.search_space
    rhs = constraint.rhs

    # reuse calculated max and min values for each index
    maxs = constraint.maxs
    mins = constraint.mins
    pre_maxs = constraint.pre_maxs
    pre_mins = constraint.pre_mins

    # for each index compute the maximum and minimum value possible
    # to fulfill the constraint
    full_max = sum(maxs) - rhs
    full_min = sum(mins) - rhs

    # if the maximum is smaller than 0 (and not even near zero)
    # or if the minimum is bigger than 0 (and not even near zero)
    # the equation can't sum to 0 => infeasible
    if full_min > com.options.atol
        com.bt_infeasible[indices] .+= 1
        return false
    end
    if full_max < -com.options.atol && constraint.is_equal
        com.bt_infeasible[indices] .+= 1
        return false
    end

    changed = true
    while changed
        changed = false
        for (i, vidx) in enumerate(indices)
            if isfixed(search_space[vidx])
                continue
            end
            # minimum without current index
            c_min = full_min - mins[i]

            # maximum without current index
            c_max = full_max - maxs[i]

            p_max = -c_min
            if p_max < maxs[i]
                maxs[i] = p_max
            end

            if constraint.is_equal
                p_min = -c_max
                if p_min > mins[i]
                    mins[i] = p_min
                end
            end
        end

        # update all
        for (i, vidx) in enumerate(indices)
            # if the maximum of coefficient * variable got reduced
            # get a safe threshold because of floating point errors
            if maxs[i] < pre_maxs[i]
                if fct.terms[i].coefficient > 0
                    threshold =
                        get_safe_upper_threshold(com, maxs[i], fct.terms[i].coefficient)
                    still_feasible = remove_above!(com, search_space[vidx], threshold)
                else
                    threshold =
                        get_safe_lower_threshold(com, maxs[i], fct.terms[i].coefficient)
                    still_feasible = remove_below!(com, search_space[vidx], threshold)
                end
                full_min, full_max, new_min, new_max = get_new_extrema_and_sum(
                    search_space,
                    vidx,
                    i,
                    fct.terms,
                    full_min,
                    full_max,
                    pre_mins,
                    pre_maxs,
                )
                changed = set_new_extrema(i, pre_mins, pre_maxs, new_min, new_max)
                mins[i] = pre_mins[i]
                maxs[i] = pre_maxs[i]
                !still_feasible && return false
            end
            # same if a better minimum value could be achieved
            if mins[i] > pre_mins[i]
                new_min = pre_mins[i]
                new_max = pre_maxs[i]
                if fct.terms[i].coefficient > 0
                    threshold =
                        get_safe_lower_threshold(com, mins[i], fct.terms[i].coefficient)
                    still_feasible = remove_below!(com, search_space[vidx], threshold)
                else
                    threshold =
                        get_safe_upper_threshold(com, mins[i], fct.terms[i].coefficient)
                    still_feasible = remove_above!(com, search_space[vidx], threshold)
                end
                full_min, full_max, new_min, new_max = get_new_extrema_and_sum(
                    search_space,
                    vidx,
                    i,
                    fct.terms,
                    full_min,
                    full_max,
                    pre_mins,
                    pre_maxs,
                )
                changed = set_new_extrema(i, pre_mins, pre_maxs, new_min, new_max)
                mins[i] = pre_mins[i]
                maxs[i] = pre_maxs[i]

                !still_feasible && return false
            end
        end
    end

    # the following is only for an equal constraint
    !constraint.is_equal && return true
    n_unfixed = count_unfixed(com, constraint)
    n_unfixed != 2 && return true

    return prune_is_equal_two_var!(com, constraint, fct)
end

"""
    prune_is_equal_two_var!(com::CS.CoM,
        constraint::CS.LinearConstraint,
        fct::SAF{T}) where T

Prune something like ax+by+cz == d with a,b,c,d constants and x,y,z variables
where only two variables aren't fixed yet. One should make sure with [`count_unfixed`](@ref)
that this is the case.
Return whether feasible
"""
function prune_is_equal_two_var!(com::CS.CoM,
    constraint::CS.LinearConstraint,
    fct::SAF{T}) where T

    search_space = com.search_space

    fixed_rhs = get_fixed_rhs(com, constraint)

    local_vidx_1, vidx_1, local_vidx_2, vidx_2 = get_two_unfixed(com, constraint)
    var1 = com.search_space[vidx_1]
    var2 = com.search_space[vidx_2]
    both_in_same_all_different = any(var1.in_all_different .& var2.in_all_different)
    for ((this_local_vidx, this_vidx), (other_local_vidx, other_vidx)) in zip(
        ((local_vidx_1, vidx_1), (local_vidx_2, vidx_2)),
        ((local_vidx_2, vidx_2), (local_vidx_1, vidx_1))
    )
        this_var = search_space[this_vidx]
        other_var = search_space[other_vidx]
        for val in values(this_var)
            # if we choose this value but the other wouldn't be an integer
            # => remove this value
            if !isapprox_divisible(
                com,
                (fixed_rhs - val * fct.terms[this_local_vidx].coefficient),
                fct.terms[other_local_vidx].coefficient,
            )
                if !rm!(com, this_var, val)
                    return false
                end
                continue
            end

            remainder = fixed_rhs - val * fct.terms[this_local_vidx].coefficient
            remainder /= fct.terms[other_local_vidx].coefficient
            remainder_int = get_approx_discrete(remainder)
            if !has(other_var, remainder_int)
                !rm!(com, this_var, val) && return false
                continue
            end
            # if in same all different and the remainder equals the value
            # like x+y = 2x
            if both_in_same_all_different && remainder_int == val
                !rm!(com, this_var, val) && return false
                !rm!(com, other_var, val) && return false
            end
        end
    end

    # if only one is unfixed => fix it
    var_1 = search_space[vidx_1]
    var_2 = search_space[vidx_2]
    if isfixed(var_1) || isfixed(var_2)
        if isfixed(var_1)
            unfixed_var = var_2
            unfixed_local_idx = local_vidx_2
            fixed_local_idx = local_vidx_1
        else
            unfixed_var = var_1
            unfixed_local_idx = local_vidx_1
            fixed_local_idx = local_vidx_2
        end
        fixed_coeff = fct.terms[fixed_local_idx].coefficient
        unfixed_coeff = fct.terms[unfixed_local_idx].coefficient
        if isfixed(var_1)
            fixed_rhs -= fixed_coeff*value(var_1)
        else
            fixed_rhs -= fixed_coeff*value(var_2)
        end
        !isapprox_divisible(com, fixed_rhs, unfixed_coeff) && return false
        remainder = fixed_rhs
        remainder /= unfixed_coeff
        remainder_int = get_approx_discrete(remainder)
        !has(unfixed_var, remainder_int) && return false
        !fix!(com, unfixed_var, remainder_int) && return false
    end
    return true
end

"""
    still_feasible(com::CoM, constraint::LinearConstraint, fct::SAF{T},
                   set::MOI.EqualTo{T}, vidx::Int, val::Int) where T <: Real

Return whether setting `search_space[vidx]` to `val` is still feasible given `constraint`.
"""
function still_feasible(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::Union{MOI.LessThan, MOI.EqualTo, CPE.Strictly{ MOI.LessThan{T}}},
    vidx::Int,
    val::Int,
) where {T<:Real}
    search_space = com.search_space
    rhs = constraint.rhs
    csum = 0
    num_not_fixed = 0
    not_fixed_idx = 0
    not_fixed_i = 0
    max_extra = 0
    min_extra = 0
    for (i, cvidx) in enumerate(constraint.indices)
        if cvidx == vidx
            csum += val * fct.terms[i].coefficient
            continue
        end
        if isfixed(search_space[cvidx])
            csum += CS.value(search_space[cvidx]) * fct.terms[i].coefficient
        else
            num_not_fixed += 1
            not_fixed_idx = cvidx
            not_fixed_i = i
            if fct.terms[i].coefficient >= 0
                max_extra += search_space[cvidx].max * fct.terms[i].coefficient
                min_extra += search_space[cvidx].min * fct.terms[i].coefficient
            else
                min_extra += search_space[cvidx].max * fct.terms[i].coefficient
                max_extra += search_space[cvidx].min * fct.terms[i].coefficient
            end
        end
    end
    if num_not_fixed == 0
        if constraint.is_equal
            return isapprox(csum, rhs; atol = com.options.atol, rtol = com.options.rtol)
        else
            if constraint.is_strict
                return csum < constraint.strict_rhs
            else
                return csum <= rhs
            end
        end
    end
    if num_not_fixed == 1 && constraint.is_equal
        if isapprox_divisible(com, rhs - csum, fct.terms[not_fixed_i].coefficient)
            return has(
                search_space[not_fixed_idx],
                get_approx_discrete((rhs - csum) / fct.terms[not_fixed_i].coefficient),
            )
        else
            return false
        end
    end

    if csum + min_extra > rhs + com.options.atol
        return false
    end

    if constraint.is_equal && csum + max_extra < rhs - com.options.atol
        return false
    end

    return true
end

"""
    is_constraint_solved(
        com::CS.CoM,
        constraint::LinearConstraint,
        fct::SAF{T},
        set::MOI.LessThan{T},
    )

    Check if the constraint is fulfilled even though not all variables are set
"""
function is_constraint_solved(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T},
) where T
    sum_maxs = sum(constraint.maxs)
    return sum_maxs <= MOI.constant(set)
end

"""
    is_constraint_solved(
        com::CS.CoM,
        constraint::LinearConstraint,
        fct::SAF{T},
        set::CPE.Strictly{MOI.LessThan{T}}
    )

    Check if the constraint is fulfilled even though not all variables are set
"""
function is_constraint_solved(
    com::CS.CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::CPE.Strictly{MOI.LessThan{T}},
) where T
    sum_maxs = sum(constraint.maxs)
    return sum_maxs < MOI.constant(set)
end

function is_constraint_solved(
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.EqualTo{T},
    values::Vector{Int}
) where {T<:Real}
    return sum(values .* constraint.coeffs) + fct.constant ≈ set.value
end

function is_constraint_solved(
    constraint::LinearConstraint,
    fct::SAF{T},
    set::MOI.LessThan{T},
    values::Vector{Int}
) where {T<:Real}
    return sum(values .* constraint.coeffs) + fct.constant <= set.upper
end


function is_constraint_solved(
    constraint::LinearConstraint,
    fct::SAF{T},
    set::CPE.Strictly{MOI.LessThan{T}},
    values::Vector{Int}
) where {T<:Real}
    return sum(values .* constraint.coeffs) + fct.constant < set.set.upper
end


"""
    is_constraint_violated(
        com::CoM,
        constraint::LinearConstraint,
        fct::SAF{T},
        set::Union{MOI.LessThan, MOI.EqualTo, CPE.Strictly{MOI.LessThan{T}}}
    ) where {T<:Real}

Checks if the constraint is violated as it is currently set. This can happen inside an
inactive reified or indicator constraint.
"""
function is_constraint_violated(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::Union{MOI.LessThan, MOI.EqualTo, CPE.Strictly{MOI.LessThan{T}}},
) where {T<:Real}
    if all(isfixed(var) for var in com.search_space[constraint.indices])
        return !is_constraint_solved(
            constraint,
            fct,
            set,
            CS.value.(com.search_space[constraint.indices]),
        )
    end
    # check if it can be feasible using the minimum sum
    return !min_sum_feasible(com, sum(constraint.mins), set)
end

"""
    min_sum_feasible(min_sum, set::Union{MOI.LessThan, MOI.EqualTo}) 

Check if the minimum sum is <= set value + absolute tolerance 
"""
function min_sum_feasible(com, min_sum, set::Union{MOI.LessThan, MOI.EqualTo})
    return min_sum <= MOI.constant(set) + com.options.atol
end

function min_sum_feasible(com, min_sum, set::CPE.Strictly{MOI.LessThan{T}}) where T
    if isapprox_discrete(com, min_sum) && isapprox_discrete(com, MOI.constant(set))
        return get_approx_discrete(min_sum) < get_approx_discrete(MOI.constant(set))
    end
    return min_sum <= MOI.constant(set) + com.options.atol
end

function _reverse_pruning_constraint!(
    com::CoM,
    constraint::LinearConstraint,
    fct::SAF{T},
    set::Union{MOI.LessThan, MOI.EqualTo, CPE.Strictly{MOI.LessThan{T}}},
    backtrack_id::Int,
) where {T <: Real}
    recompute_lc_extrema!(com, constraint, fct)
end
"""
    simplify!(com)

Simplify constraints i.e by adding new constraints which uses an implicit connection between two constraints.
i.e an `all_different` does sometimes include information about the sum.
Return a list of newly added constraint ids
"""
function simplify!(com)
    added_constraint_idxs = Int[]
    # check if we have all_different and sum constraints
    b_all_different = false
    # (all different where every value is used)
    b_all_different_sum = false
    b_equal_to = false
    # != constraint
    b_not_equal_to = false
    b_svc_less_than = false
    for constraint in com.constraints
        if isa(constraint.set, AllDifferentSetInternal)
            b_all_different = true
            if length(constraint.indices) == length(constraint.pvals)
                b_all_different_sum = true
            end
        elseif isa(constraint.fct, SAF) && isa(constraint.set, MOI.EqualTo)
            b_equal_to = true
        elseif isa(constraint.fct, SAF) && isa(constraint.set, CS.NotEqualTo)
            b_not_equal_to = true
        elseif isa(constraint, SingleVariableConstraint) && isa(constraint.set, MOI.LessThan)
            b_svc_less_than = true
        end
    end
    if b_all_different_sum && b_equal_to
        append!(added_constraint_idxs, simplify_all_different_and_equal_to(com))
    end
    if b_not_equal_to
        append!(added_constraint_idxs, simplify_not_equal_to_cliques(com))
    end
    if b_svc_less_than
        append!(added_constraint_idxs, simplify_svc_less_than(com))
    end

    if length(added_constraint_idxs) > 0 && :Info in com.options.logging
        println("Added $(length(added_constraint_idxs)) new constraints")
    end
    return added_constraint_idxs
end

function simplify_svc_less_than(com)
    added_constraint_idxs = Int[]
    # save all variables, constraints of the form a <= b
    lhs_vars = Dict{Int, Vector{Int}}()
    lhs_cons = Dict{Int, Vector{Int}}()
    # save all variables, constraints of the form a >= b
    rhs_vars = Dict{Int, Vector{Int}}()
    rhs_cons = Dict{Int, Vector{Int}}()
    for constraint_idx = 1:length(com.constraints)
        constraint = com.constraints[constraint_idx]
        if isa(constraint, SingleVariableConstraint) && isa(constraint.set, MOI.LessThan)
            if haskey(lhs_vars, constraint.lhs)
                push!(lhs_vars[constraint.lhs], constraint.rhs)
                push!(lhs_cons[constraint.lhs], constraint.idx)
            else
                lhs_vars[constraint.lhs] = [constraint.rhs]
                lhs_cons[constraint.lhs] = [constraint.idx]
            end

            if haskey(rhs_vars, constraint.rhs)
                push!(rhs_vars[constraint.rhs], constraint.lhs)
                push!(rhs_cons[constraint.rhs], constraint.idx)
            else
                rhs_vars[constraint.rhs] = [constraint.lhs]
                rhs_cons[constraint.rhs] = [constraint.idx]
            end
        end
    end

    # check for >= which constraint appears >= 5 times on the left side
    # Todo: Do the same for lhs_vars with LeqSet
    for (key, value) in rhs_vars
        if length(value) >= 5
            # add new all different constraint
            set = GeqSetInternal(1+length(value))
            vars = MOI.VectorOfVariables([MOI.VariableIndex(key), [MOI.VariableIndex(vidx) for vidx in value]...])
            internals = ConstraintInternals(
                length(com.constraints) + 1,
                vars,
                set,
                Int[v.value for v in vars.variables]
            )

            constraint = init_constraint_struct(GeqSetInternal, internals)
            add_constraint!(com, constraint)
            push!(added_constraint_idxs, length(com.constraints))

            for cidx in rhs_cons[key]
                com.constraints[cidx].is_deactivated = true
            end
        end
    end

    return added_constraint_idxs
end

"""
    simplify_not_equal_to_cliques(com)

Combine simple `a != b` constraints to `alldifferent` constraints using maximal cliques
"""
function simplify_not_equal_to_cliques(com)
    added_constraint_idxs = Int[]
    simple_not_equal_constraints = Int[]
    # one node per variable which is part of != constraint
    nodes = Set()
    # check for simple != constraints like `a != b`
    for constraint_idx = 1:length(com.constraints)
        constraint = com.constraints[constraint_idx]

        if isa(constraint.set, CS.NotEqualTo) && length(constraint.indices) == 2
            if constraint.fct.terms[1].coefficient == -constraint.fct.terms[2].coefficient &&
                abs(constraint.fct.terms[1].coefficient) == 1

                if constraint.fct.constant == 0 && constraint.set.value == 0
                    push!(simple_not_equal_constraints, constraint_idx)
                    for vidx in constraint.indices
                        push!(nodes, vidx)
                    end
                end
            end
        end
    end


    g = SimpleGraph(length(nodes))
    variables_to_constraint = Dict{Tuple{Int, Int}, Int}()
    for constraint_idx in simple_not_equal_constraints
        constraint = com.constraints[constraint_idx]
        add_edge!(g, constraint.indices[1], constraint.indices[2])
        variables_to_constraint[(constraint.indices[1], constraint.indices[2])] = constraint_idx
    end
    cliques = maximal_cliques(g)
    for clique in cliques
        clique_size = length(clique)
        # use cliques if they contain at least 4 nodes
        if clique_size >= 4
            # add new all different constraint
            set = AllDifferentSetInternal(clique_size)
            vars = MOI.VectorOfVariables([MOI.VariableIndex(vidx) for vidx in clique])
            internals = ConstraintInternals(
                length(com.constraints) + 1,
                vars,
                set,
                Int[v.value for v in vars.variables]
            )

            constraint = init_constraint_struct(AllDifferentSetInternal, internals)
            add_constraint!(com, constraint)
            push!(added_constraint_idxs, length(com.constraints))

            # deactivate old constraints
            for first_idx in 1:clique_size
                for second_idx in first_idx+1:clique_size
                    constraint_idx = get(variables_to_constraint, (clique[first_idx], clique[second_idx]), 0)
                    if constraint_idx != 0
                        com.constraints[constraint_idx].is_deactivated = true
                    end
                end
            end
        end
    end

    return added_constraint_idxs
end

"""
    simplify_all_different_and_equal_to(com)

Several functions to combine all_different constraints and equal to constraints
to add new equal to constraints
"""
function simplify_all_different_and_equal_to(com)
    added_constraint_idxs = Int[]
    # for each all_different constraint
    # which has an implicit sum constraint
    # check which sum constraints are completely inside all different
    # which are partially inside
    # compute inside sum and total sum
    n_constraints_before = length(com.constraints)
    for constraint_idx = 1:length(com.constraints)
        constraint = com.constraints[constraint_idx]

        if isa(constraint.set, AllDifferentSetInternal)
            # check that the all different constraint uses every value
            if length(constraint.indices) == length(constraint.pvals)
                append!(added_constraint_idxs, simplify_all_different_inner_equal_to(com, constraint))
                append!(added_constraint_idxs, simplify_all_different_outer_equal_to(com, constraint, n_constraints_before))
            end
        end
    end
    return added_constraint_idxs
end

"""
    simplify_all_different_inner_equal_to(com, constraint::AllDifferentConstraint)

Add new sum constraint inside an alldifferent constraint to get restrict some variables more.
This function checks all sum constraints which are completely inside of the alldifferent constraint.

# Example
- [a,b,c,d,e] is the `AllDifferentConstraint`
- [a,b,c] is a sum constraint
- Add a new sum constraint for [d,e]
"""
function simplify_all_different_inner_equal_to(com, constraint::AllDifferentConstraint)
    @assert length(constraint.indices) == length(constraint.pvals)
    added_constraint_idxs = Int[]
    all_diff_sum = sum(constraint.pvals)
    in_sum = 0
    found_possible_constraint = false
    outside_indices = constraint.indices
    # go over all constraints that are completely inside alldifferent
    for sc_idx in constraint.sub_constraint_idxs
        sub_constraint = com.constraints[sc_idx]
        # if it's an equal_to constraint
        if isa(sub_constraint.fct, SAF) &&
            isa(sub_constraint.set, MOI.EqualTo)
            # the coefficients must be all 1
            if all(t.coefficient == 1 for t in sub_constraint.fct.terms)
                # compute sum inside all sum constraints
                found_possible_constraint = true
                in_sum += sub_constraint.set.value -
                    sub_constraint.fct.constant
                # for sum which are in alldifferent but not in sum constraints
                outside_indices = setdiff(outside_indices, sub_constraint.indices)
            end
        end
    end
    if found_possible_constraint && length(outside_indices) <= 4
        constraint_idx = length(com.constraints)+1
        # all_diff_sum is Int and in_sum must be as well as all variables are Int and coefficients 1
        lc = LinearConstraint(
            constraint_idx, outside_indices, ones(Int, length(outside_indices)),
            0, MOI.EqualTo{Int}(all_diff_sum - in_sum)
        )
        add_constraint!(
            com,
            lc
        )
        push!(added_constraint_idxs, constraint_idx)
    end
    return added_constraint_idxs
end

"""
    simplify_all_different_outer_equal_to(com, constraint::AllDifferentConstraint)

check if several sum constraints completely fill the sum constraint
if this is the case we can use the sum of the all different constraint
to get useful information about the sum of variables outside the
all different constraint but inside one of the sum constraints

# Example
[a,b,c,d] where [a,b,c] are in alldifferent and sum is 6
[a,b] in sum constraint == 3
[c,d] in sum constraint == 9
=> 6+d == 12 => d=6
"""
function simplify_all_different_outer_equal_to(com, constraint::AllDifferentConstraint, n_constraints_before)
    @assert length(constraint.indices) == length(constraint.pvals)
    add_sum_constraint = true
    all_diff_sum = sum(constraint.pvals)
    added_constraint_idxs = []

    total_sum = 0
    outside_indices = Int[]
    cons_indices_dict = arr2dict(constraint.indices)
    for variable_idx in keys(cons_indices_dict)
        found_sum_constraint = false
        for sub_constraint_idx in com.subscription[variable_idx]
            # don't mess with constraints added later on
            if sub_constraint_idx > n_constraints_before
                continue
            end
            sub_constraint = com.constraints[sub_constraint_idx]
            # it must be an equal constraint and all coefficients must be 1 otherwise we can't add a constraint
            if isa(sub_constraint.fct, SAF) &&
                isa(sub_constraint.set, MOI.EqualTo)
                if all(t.coefficient == 1 for t in sub_constraint.fct.terms)
                    found_sum_constraint = true
                    total_sum +=
                        sub_constraint.set.value -
                        sub_constraint.fct.constant
                    all_inside = true
                    for sub_variable_idx in sub_constraint.indices
                        if !haskey(cons_indices_dict, sub_variable_idx)
                            all_inside = false
                            push!(outside_indices, sub_variable_idx)
                        else
                            delete!(cons_indices_dict, sub_variable_idx)
                        end
                    end
                    break
                end
            end
        end
        if !found_sum_constraint
            add_sum_constraint = false
            break
        end
    end

    # make sure that there are not too many outside indices
    if add_sum_constraint && length(outside_indices) <= 4
        constraint_idx = length(com.constraints)+1
        lc = LinearConstraint(
            constraint_idx, outside_indices, ones(Int, length(outside_indices)),
            0, MOI.EqualTo{Int}(total_sum - all_diff_sum)
        )
        add_constraint!(
            com,
            lc
        )
        push!(added_constraint_idxs, constraint_idx)
    end
    return added_constraint_idxs
end

"""
    recompute_subscriptions(com)

Reset all subscriptions and recomputes them to only point to constraints that aren't deactivated
"""
function recompute_subscriptions(com)
    for variable in com.search_space
        empty!(com.subscription[variable.idx])
    end
    for constraint in com.constraints
        constraint.is_deactivated && continue
        for vidx in constraint.indices
            push!(com.subscription[vidx], constraint.idx)
        end
    end
end

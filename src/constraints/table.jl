include("table/support.jl")
include("table/residues.jl")
include("table/RSparseBitSet.jl")
    
"""
    init_constraint!(com::CS.CoM, constraint::TableConstraint, fct::MOI.VectorOfVariables, set::TableSetInternal)

"""
function init_constraint!(
    com::CS.CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
)
    table = set.table
    num_pos_rows = size(table, 1)

    possible_rows = trues(num_pos_rows)
    search_space = com.search_space

    indices = constraint.std.indices
    for row_id in 1:size(table)[1]
        for (i, vidx) in enumerate(indices)
            if !has(search_space[vidx], table[row_id, i])
                possible_rows[row_id] = false
                num_pos_rows -= 1
                break
            end
        end
    end
    num_pos_rows == 0 && return false
    pos_rows_idx = findall(possible_rows)
    row_sums = nothing

    # if there is an lp model we compute bounds for the sum
    if com.lp_model !== nothing
        row_sums = sum(table[possible_rows,:]; dims=2)[:,1]
        local_sort_perm = sortperm(row_sums)
        row_sums = row_sums[local_sort_perm]
        # initial bounds for sum(variables[indices])
        table_min = row_sums[1]
        table_max = row_sums[end]
        pos_rows_idx = pos_rows_idx[local_sort_perm]
        
        lp_backend = backend(com.lp_model)
        lp_var_idx = create_lp_variable!(com.lp_model, com.lp_x; lb=table_min, ub=table_max)
        # create == constraint with sum of all variables equal the newly created variable
        sats = [MOI.ScalarAffineTerm(1.0, MOI.VariableIndex(var_idx)) for var_idx in indices]
        push!(sats, MOI.ScalarAffineTerm(-1.0, MOI.VariableIndex(lp_var_idx)))
        saf = MOI.ScalarAffineFunction(sats, 0.0)
        MOI.add_constraint(lp_backend, saf, MOI.EqualTo(0.0))
        constraint.std.bound_rhs = [BoundRhsVariable(lp_var_idx, table_min, table_max)]
    end
    

    support = constraint.supports
    
    support.var_start = cumsum([length(search_space[vidx].init_vals) for vidx in indices])
    support.var_start .+= 1
    num_supports = support.var_start[end]-1

    pushfirst!(support.var_start, 1)
    # println("var_start: $(support.var_start)")
    num_64_words = cld(num_pos_rows, 64)
    # println("num_64_words: $num_64_words")

    # define RSparseBitSet
    rsbs = constraint.current
    rsbs.words = fill(~zero(UInt64), num_64_words)
    rsbs.indices = 1:num_64_words
    rsbs.last_ptr = num_64_words
    rsbs.mask = fill(~zero(UInt64), num_64_words)
    rsbs.temp_mask = zeros(UInt64, num_64_words)
    ending_ones = (num_pos_rows-1) % 64 +1
    rsbs.words[end] = rsbs.words[end] .⊻ ((UInt64(1) << (64-ending_ones))-1)

    support.values = zeros(UInt64, (num_64_words, num_supports))
    # if we have an LP model we store sum_min and sum_max for each 64 block
    if row_sums !== nothing
        constraint.sum_min = zeros(Int64, num_64_words)
        constraint.sum_max = fill(row_sums[end], num_64_words)
    end

    num_64_idx = 0
    rp_idx = 0
    for r in pos_rows_idx
        rp_idx += 1
        if rp_idx % 64 == 1
            num_64_idx += 1
        end
        if row_sums !== nothing
            # store the smallest number in the block
            if rp_idx % 64 == 1
                constraint.sum_min[num_64_idx] = row_sums[rp_idx]
            elseif rp_idx % 64 == 0 # store the biggest number in the block
                constraint.sum_max[num_64_idx] = row_sums[rp_idx]
            end
        end
        for (c, vidx) in enumerate(indices)
            variable = search_space[vidx]
            var_offset = variable.offset
            table_val = table[r,c]
            val_idx = variable.init_val_to_index[table_val + var_offset]
            @assert variable.init_vals[val_idx] == table_val
            support_col_idx = support.var_start[c]+val_idx-1
            # println("support_col_idx: $support_col_idx")
            cell_64 = support.values[num_64_idx, support_col_idx]
            pos_in_64 = (rp_idx-1) % 64 + 1
            support.values[num_64_idx, support_col_idx] = cell_64 .| (UInt64(1) << (64-pos_in_64))
        end
    end

    # check if a support column is completely zero
    # that means that the variable corresponding to that column can't have the value corresponding to the column 
    feasible = true
    for c = 1:num_supports
        if all(i->i==UInt64(0), support.values[:,c])
            # getting the correct index in indices
            var_i = 1
            while support.var_start[var_i] <= c
                var_i += 1
            end
            var_i -= 1
            val_i = c-support.var_start[var_i]+1
            var = indices[var_i]
            val = search_space[var].init_vals[val_i]
            if has(search_space[var], val)
                feasible = rm!(com, search_space[var], val)
                if !feasible  
                    break
                end
            end
        end
    end
    !feasible && return false

    # define residues
    residues = constraint.residues
    residues.var_start = copy(support.var_start)
    residues.values = zeros(Int, num_supports)
    for sc=1:num_supports
        idx = support.values[:,sc]
        residues.values[sc] = intersect_index(rsbs, idx)
        @assert residues.values[sc] <= num_64_words
    end

    # define last_sizes
    constraint.last_sizes = [CS.nvalues(com.search_space[vidx]) for vidx in indices]
    return feasible
end

function update_table(com::CoM, constraint::TableConstraint)
    current = constraint.current
    supports = constraint.supports
    indices = constraint.std.indices
    variables = com.search_space
    backtrack_idx = com.c_backtrack_idx
    for local_vidx in constraint.changed_vars
        vidx = indices[local_vidx]
        var = variables[vidx]
        clear_mask(current)
        nremoved = num_removed(var, backtrack_idx)
        if nremoved < nvalues(var)
            for value in view_removed_values(variables[vidx], nremoved)
                add_to_mask(current, supports[com, local_vidx, value])
            end
            invert_mask(current)
        else
            # reset based update
            for value in view_values(var)
                add_to_mask(current, supports[com, local_vidx, value])
            end
        end
       
        intersect_with_mask(current)
        is_empty(current) && break
    end
end

function filter_domains(com::CoM, constraint::TableConstraint)
    current = constraint.current
    supports = constraint.supports
    residues = constraint.residues
    indices = constraint.std.indices
    variables = com.search_space
    feasible = true
    changed = false
    for local_vidx in constraint.unfixed_vars
        vidx = indices[local_vidx]
        for value in CS.values(variables[vidx])
            idx = residues[com, local_vidx, value]
            if current.words[idx] & supports[com, local_vidx, value][idx] == UInt64(0)
                idx = intersect_index(current, supports[com, local_vidx, value])
                if idx != 0
                    residues[com, local_vidx, value] = idx
                else
                    if has(variables[vidx], value)
                        changed = true
                        if !rm!(com, variables[vidx], value)
                            feasible = false
                            break
                        end
                        @assert !has(variables[vidx], value) 
                    end
                end 
            end
        end
        constraint.last_sizes[local_vidx] = CS.nvalues(variables[vidx])
        !feasible && break
    end
    return feasible, changed
end

"""
    prune_constraint!(com::CS.CoM, constraint::TableConstraint, fct::MOI.VectorOfVariables, set::TableSetInternal; logs = true)

Reduce the number of possibilities given the `TableConstraint`.
Return whether still feasible and throws a warning if infeasible and `logs` is set to `true`
"""
function prune_constraint!(
    com::CS.CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal;
    logs = true,
)
    current = constraint.current
    indices = constraint.std.indices
    variables = com.search_space

    changed = true
    feasible = true
    while changed
        # All local indices (1 corresponds to indices[1]) which have changed
        constraint.changed_vars = findall(x->CS.nvalues(variables[indices[x]]) != constraint.last_sizes[x], 1:length(indices))
        for local_vidx in constraint.changed_vars
            constraint.last_sizes[local_vidx] = CS.nvalues(variables[indices[local_vidx]])
        end
        constraint.unfixed_vars = findall(x->constraint.last_sizes[x] > 1, 1:length(indices))
        if length(constraint.changed_vars) != 0
            update_table(com, constraint)
            if is_empty(current) 
                feasible = false
                break
            end
        end
        
        feasible, changed = filter_domains(com, constraint)
        !feasible && break
    end
    empty!(constraint.changed_vars)
    # full mask for `single_reverse_pruning_constraint!``
    full_mask(current)
    return feasible
end

"""
    still_feasible(com::CoM, constraint::TableConstraint, fct::MOI.VectorOfVariables, set::TableSetInternal, value::Int, index::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `index` to `value`.
"""
function still_feasible(
    com::CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    value::Int,
    index::Int,
)
    current = constraint.current
    supports = constraint.supports
    indices = constraint.std.indices
    full_mask(current)
    for i = 1:length(indices)
        if indices[i] == index
            intersect_mask_with_mask(current, supports[com, i, value])
        elseif isfixed(com.search_space[indices[i]])
            intersect_mask_with_mask(current, supports[com, i, CS.value(com.search_space[indices[i]])])
        end
    end
    feasible = intersect_with_mask_feasible(current)

    full_mask(current)
    return feasible
end


"""
    update_best_bound_constraint!(com::CS.CoM,
        constraint::TableConstraint,
        fct::MOI.VectorOfVariables,
        set::TableSetInternal,
        var_idx::Int,
        lb::Int,
        ub::Int
    )

Update the bound constraint associated with this constraint. This means that the `bound_rhs` bounds will be changed according to 
the possible values the table constraint allows. `var_idx`, `lb` and `ub` don't are not considered atm.
Additionally only a rough estimated bound is used which can be computed relatively fast. 
"""
function update_best_bound_constraint!(com::CS.CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    var_idx::Int,
    lb::Int,
    ub::Int
)
    constraint.std.bound_rhs === nothing && return
    sum_min = constraint.sum_min
    sum_max = constraint.sum_max
    bitset = constraint.current
    
    bound_rhs = constraint.std.bound_rhs[1]

    lb = typemax(Int)
    ub = typemin(Int)

    @inbounds for i=1:bitset.last_ptr
        idx = bitset.indices[i]
        lb = min(lb, sum_min[idx])
        ub = max(ub, sum_max[idx])
    end
    bound_rhs.lb = lb
    bound_rhs.ub = ub
end

"""
    single_reverse_pruning_constraint!(
        com::CoM,
        constraint::TableConstraint,
        fct::MOI.VectorOfVariables,
        set::TableSetInternal,
        var_idx::Int,
        changes::Vector{Tuple{Symbol,Int,Int,Int}}
    )

It gets called after the variables returned to their state after backtracking.
A single reverse pruning step for the TableConstraint. 
Add the removed values to the mask and in `reverse_pruning_constraint` the corresponding table rows 
will be reactivated.
"""
function single_reverse_pruning_constraint!(
    com::CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    var_idx::Int,
    changes::Vector{Tuple{Symbol,Int,Int,Int}}
)
    current = constraint.current
    variables = com.search_space
    supports = constraint.supports
    residues = constraint.residues
    indices = constraint.std.indices
    local_var_idx = 1
    while local_var_idx <= length(indices)
        if var_idx == indices[local_var_idx]
            break
        end
        local_var_idx += 1
    end
    @assert local_var_idx <= length(indices)
    @assert indices[local_var_idx] == var_idx

    push!(constraint.changed_vars, local_var_idx)
    
    var = variables[var_idx]
    constraint.last_sizes[local_var_idx] = CS.nvalues(var)
    clear_temp_mask(current)
    for val in view_values(var)
        add_to_temp_mask(current, supports[com, local_var_idx, val])
    end
    intersect_mask_with_mask_full(current, current.temp_mask)
end

"""
    reset_residues!(com, constraint::TableConstraint)

Reset residues for constraint.changed_vars
"""
function reset_residues!(com, constraint::TableConstraint)
    support = constraint.supports
    residues = constraint.residues
    current = constraint.current
    indices = constraint.std.indices
    variables = com.search_space
    num_residues = length(residues.values)
    for local_var_idx in constraint.changed_vars
        var_idx = indices[local_var_idx]
        var = variables[var_idx]
        for val_idx in var.first_ptr:var.last_ptr
            new_residue = intersect_index(current, support[com, local_var_idx, var.values[val_idx]])
            if new_residue != 0
                residues[com, local_var_idx, var.values[val_idx]] = new_residue
            end
        end
    end
end

"""
    reverse_pruning_constraint!(
        com::CoM,
        constraint::TableConstraint,
        fct::MOI.VectorOfVariables,
        set::TableSetInternal,
    )

Is called after `single_reverse_pruning_constraint!`.
Reverse intersect with mask to reactivate the removed table rows.
"""
function reverse_pruning_constraint!(
    com::CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
)
    isempty(constraint.changed_vars) && return
    current = constraint.current
    rev_intersect_with_mask(current)
    full_mask(current)
    reset_residues!(com, constraint)
    empty!(constraint.changed_vars)
end
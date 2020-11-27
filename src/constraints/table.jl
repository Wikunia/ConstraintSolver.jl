include("table/support.jl")
include("table/residues.jl")
include("table/RSparseBitSet.jl")

function init_constraint_struct(::Type{TableSetInternal}, internals)
    TableConstraint(
        internals,
        RSparseBitSet(),
        TableSupport(), # will be filled in init_constraint!
        Int[], # will be changes later as it needs the number of words
        TableResidues(),
        Vector{TableBacktrackInfo}(),
        Int[], # changed_vars
        Int[], # unfixed_vars
        Int[], # sum_min
        Int[]  # sum_max
    )
end

"""
    init_constraint!(com::CS.CoM, constraint::TableConstraint, fct::MOI.VectorOfVariables, set::TableSetInternal;
                    active = true)

"""
function init_constraint!(
    com::CS.CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal;
    active = true
)
    table = set.table
    num_pos_rows = size(table, 1)

    possible_rows = trues(num_pos_rows)
    search_space = com.search_space

    indices = constraint.indices
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
        # if not active (inside an indicator constraint)
        # don't have any bounds
        if !active
            table_min = typemin(Int)
            table_max = typemax(Int)
        end
        pos_rows_idx = pos_rows_idx[local_sort_perm]

        lp_backend = backend(com.lp_model)
        lp_vidx = create_lp_variable!(com.lp_model, com.lp_x; lb=table_min, ub=table_max)
        # create == constraint with sum of all variables equal the newly created variable
        sats = [MOI.ScalarAffineTerm(1.0, MOI.VariableIndex(vidx)) for vidx in indices]
        push!(sats, MOI.ScalarAffineTerm(-1.0, MOI.VariableIndex(lp_vidx)))
        saf = MOI.ScalarAffineFunction(sats, 0.0)
        MOI.add_constraint(lp_backend, saf, MOI.EqualTo(0.0))
        constraint.bound_rhs = [BoundRhsVariable(lp_vidx, table_min, table_max)]
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
    if active
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
    indices = constraint.indices
    variables = com.search_space
    backtrack_idx = com.c_backtrack_idx
    for local_vidx in constraint.changed_vars
        vidx = indices[local_vidx]
        var = variables[vidx]
        clear_mask(current)
        if num_removed(var) < nvalues(var) && !isfixed(var)
            for value in view_removed_values(var)
                support = get_view(supports, com, vidx, local_vidx, value)
                add_to_mask(current, support)
            end
            invert_mask(current)
        else
            # reset based update
            for value in view_values(var)
                support = get_view(supports, com, vidx, local_vidx, value)
                add_to_mask(current, support)
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
    indices = constraint.indices
    variables = com.search_space
    feasible = true
    changed = false
    for local_vidx in constraint.unfixed_vars
        vidx = indices[local_vidx]
        for value in CS.values(variables[vidx])
            idx = residues[com, vidx, local_vidx, value]
            # residues is 0 when the constraint was inactive at the beginning
            if idx == 0
                if has(variables[vidx], value)
                    changed = true
                    if !rm!(com, variables[vidx], value)
                        feasible = false
                        break
                    end
                    @assert !has(variables[vidx], value)
                end
            elseif current.words[idx] & supports[com, vidx, local_vidx, value, idx] == UInt64(0)
                support = get_view(supports, com, vidx, local_vidx, value)
                idx = intersect_index(current, support)
                if idx != 0
                    residues[com, vidx, local_vidx, value] = idx
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
    indices = constraint.indices
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
    return feasible
end

function finished_pruning_constraint!(com::CS.CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal)

    @assert com.c_backtrack_idx > 0

    backtrack = constraint.backtrack
    while length(backtrack) < com.c_backtrack_idx
        push!(backtrack, TableBacktrackInfo(UInt64[], zero(UInt64), Int[]))
    end

    backtrack[com.c_backtrack_idx].words = copy(constraint.current.words)
    backtrack[com.c_backtrack_idx].last_ptr = constraint.current.last_ptr
    backtrack[com.c_backtrack_idx].indices = copy(constraint.current.indices)
    for (i,vidx) in enumerate(constraint.indices)
        constraint.last_sizes[i] = CS.nvalues(com.search_space[vidx])
    end
end

"""
    still_feasible(com::CoM, constraint::TableConstraint, fct::MOI.VectorOfVariables, set::TableSetInternal, vidx::Int, value::Int)

Return whether the constraint can be still fulfilled when setting a variable with index `vidx` to `value`.
"""
function still_feasible(
    com::CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    vidx::Int,
    value::Int,
)
    current = constraint.current
    supports = constraint.supports
    indices = constraint.indices
    full_mask(current)
    was_inside = false
    for i = 1:length(indices)
        if indices[i] == vidx
            was_inside = true
            support = get_view(supports, com, vidx, i, value)
            intersect_mask_with_mask(current, support)
        elseif isfixed(com.search_space[indices[i]])
            support = get_view(supports, com, indices[i], i, CS.value(com.search_space[indices[i]]))
            intersect_mask_with_mask(current, support)
        end
    end
    feasible = intersect_with_mask_feasible(current)

    was_inside && return feasible
    # check if all are fixed that it's actually solved
    # can happen inside a previously deactived constraint
    return is_constraint_feasible(com, constraint, fct, set)
end


"""
    update_best_bound_constraint!(com::CS.CoM,
        constraint::TableConstraint,
        fct::MOI.VectorOfVariables,
        set::TableSetInternal,
        vidx::Int,
        lb::Int,
        ub::Int
    )

Update the bound constraint associated with this constraint. This means that the `bound_rhs` bounds will be changed according to
the possible values the table constraint allows. `vidx`, `lb` and `ub` don't are not considered atm.
Additionally only a rough estimated bound is used which can be computed relatively fast.
"""
function update_best_bound_constraint!(com::CS.CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    vidx::Int,
    lb::Int,
    ub::Int
)
    constraint.bound_rhs === nothing && return
    sum_min = constraint.sum_min
    sum_max = constraint.sum_max
    bitset = constraint.current

    bound_rhs = constraint.bound_rhs[1]

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
        var::Variable,
        backtrack_idx::Int
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
    var::Variable,
    backtrack_idx::Int
)
    current = constraint.current
    variables = com.search_space
    supports = constraint.supports
    residues = constraint.residues
    indices = constraint.indices
    loc_vidx = 1
    vidx = var.idx
    changes = var.changes[backtrack_idx]
    while loc_vidx <= length(indices)
        if vidx == indices[loc_vidx]
            break
        end
        loc_vidx += 1
    end
    @assert loc_vidx <= length(indices)
    @assert indices[loc_vidx] == vidx

    constraint.last_sizes[loc_vidx] = CS.nvalues(variables[vidx])

    push!(constraint.changed_vars, loc_vidx)
end

"""
    reset_residues!(com, constraint::TableConstraint)

Reset residues for constraint.changed_vars
"""
function reset_residues!(com, constraint::TableConstraint)
    supports = constraint.supports
    residues = constraint.residues
    current = constraint.current
    indices = constraint.indices
    variables = com.search_space
    num_residues = length(residues.values)
    for local_vidx in constraint.changed_vars
        vidx = indices[local_vidx]
        var = variables[vidx]
        for val_idx in var.first_ptr:var.last_ptr
            support = get_view(supports, com, vidx, local_vidx, var.values[val_idx])
            new_residue = intersect_index(current, support)
            if new_residue != 0
                residues[com, vidx, local_vidx, var.values[val_idx]] = new_residue
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
"""
function reverse_pruning_constraint!(
    com::CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    backtrack_id::Int
)
    isempty(constraint.changed_vars) && return
    current = constraint.current
    if backtrack_id == 1
        current.last_ptr = length(current.words)
        current.words = fill(~zero(UInt64), current.last_ptr)
        current.indices = 1:current.last_ptr
    else
        parent = com.backtrack_vec[backtrack_id].parent_idx
        if parent <= length(constraint.backtrack) && !isempty(constraint.backtrack[parent].words)
            current.last_ptr = constraint.backtrack[parent].last_ptr
            current.words = copy(constraint.backtrack[parent].words)
            current.indices = copy(constraint.backtrack[parent].indices)
        end
        # otherwise there is nothing to reverse
    end
    reset_residues!(com, constraint)
    empty!(constraint.changed_vars)
end

"""
    restore_pruning_constraint!(
        com::CoM,
        constraint::TableConstraint,
        fct::MOI.VectorOfVariables,
        set::TableSetInternal,
    )

Is called after `restore_prune!`.
"""
function restore_pruning_constraint!(
    com::CoM,
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    prune_steps::Union{Int, Vector{Int}}
)
    # revert to the last of prune steps
    constraint.changed_vars = collect(1:length(constraint.indices))
    current = constraint.current
    backtrack_id = last(prune_steps)
    while backtrack_id > length(constraint.backtrack) || isempty(constraint.backtrack[backtrack_id].words)
        backtrack_id = com.backtrack_vec[backtrack_id].parent_idx
    end
    current.last_ptr = constraint.backtrack[backtrack_id].last_ptr
    current.words = copy(constraint.backtrack[backtrack_id].words)
    current.indices = copy(constraint.backtrack[backtrack_id].indices)
    for (i, vidx) in enumerate(constraint.indices)
        constraint.last_sizes[i] = CS.nvalues(com.search_space[vidx])
    end
    reset_residues!(com, constraint)
    empty!(constraint.changed_vars)
end

function is_constraint_solved(
    constraint::TableConstraint,
    fct::MOI.VectorOfVariables,
    set::TableSetInternal,
    values::Vector{Int}
)

    table = set.table
    return findfirst(ri->table[ri,:] == values, 1:size(table)[1]) !== nothing
end

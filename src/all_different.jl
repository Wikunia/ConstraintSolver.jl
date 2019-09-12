"""
    all_different(com::CS.CoM, indices; logs = true)

Tries to reduce the search space by the all_different constraint. 
Fixes values and then sets com.changed to true for the corresponding index.
Returns a ConstraintOutput object and throws a warning if infeasible and `logs` is set
"""
function all_different(com::CS.CoM, indices; logs = true)
    changed = Dict{CartesianIndex, Bool}()
    pruned  = Dict{CartesianIndex,Vector{Int}}()
    fixed   = Dict{CartesianIndex, Bool}()

    grid = com.grid
    search_space = com.search_space
    pvals = com.pvals
    not_val = com.not_val
    fixed_vals, unfixed_indices = fixed_vs_unfixed(grid, not_val, indices)

    fixed_vals_set = Set(fixed_vals)
    # check if one value is used more than once
    if length(fixed_vals_set) < length(fixed_vals)
        logs && @warn "The problem is infeasible"
        return ConstraintOutput(false, changed, pruned, fixed)
    end


    bfixed = false
    for i in unfixed_indices
        pruned[i] = Int[]
        @views c_search_space = search_space[i]
        for pv in fixed_vals
            if haskey(c_search_space, pv)
                delete!(c_search_space, pv)
                push!(pruned[i], pv)
                changed[i] = true
                if length(c_search_space) == 0
                    com.bt_infeasible[i] += 1
                    logs && @warn "The problem is infeasible"
                    return ConstraintOutput(false, changed, pruned, fixed)
                end

                if length(c_search_space) == 1
                    only_value = collect(keys(c_search_space))[1]
                    # check whether this is against any constraint
                    feasible = fulfills_constraints(com, i, only_value)
                    if !feasible
                        com.bt_infeasible[i] += 1
                        logs && @warn "The problem is infeasible"
                        return ConstraintOutput(false, changed, pruned, fixed)
                    end
                    delete!(search_space, i)
                    grid[i] = only_value
                    push!(pruned[i], only_value)
                    changed[i] = true
                    fixed[i] = true
                    push!(fixed_vals_set, only_value)
                    bfixed = true
                    break
                end
            end
        end
    end

    if length(fixed_vals_set) == length(indices)
        return ConstraintOutput(true, changed, pruned, fixed)
    end

    # find maximum_matching for infeasible check and Berge's lemma
    # building graph
    # ei = indices, ej = possible values
    # i.e ei=[1,2,1] ej = [1,2,2] => 1->[1,2], 2->[2]

    pval_mapping = zeros(Int, length(pvals))
    vertex_mapping = Dict{Int,Int64}()
    vertex_mapping_bw = Vector{Union{CartesianIndex,Int}}(undef, length(indices)+length(pvals))
    vc = 1
    for i in indices
        vertex_mapping_bw[vc] = i
        vc += 1
    end
    pvc = 1
    for pv in pvals
        pval_mapping[pvc] = pv
        vertex_mapping[pv] = vc
        vertex_mapping_bw[vc] = pv
        vc += 1
        pvc += 1
    end
    num_nodes = vc


    # count the number of edges
    num_edges = 0
    @inbounds for i in indices
        if grid[i] != not_val
            num_edges += 1
        else
            if haskey(search_space,i)
                num_edges += length(keys(search_space[i]))
            end
        end
    end


    ei = Vector{Int64}(undef,num_edges)
    ej = Vector{Int64}(undef,num_edges)

    # add edge from each index to the possible values
    edge_counter = 0
    vc = 0
    @inbounds for i in indices
        vc += 1
        if grid[i] != not_val
            edge_counter += 1
            ei[edge_counter] = vc
            ej[edge_counter] = vertex_mapping[grid[i]]-length(indices)
        else
            for pv in keys(search_space[i])
                edge_counter += 1
                ei[edge_counter] = vc
                ej[edge_counter] = vertex_mapping[pv]-length(indices)
            end
        end
    end

    # find maximum matching (weights are 1)
    _weights = ones(Bool,num_edges)
    maximum_matching = bipartite_matching(_weights,ei, ej)
    if maximum_matching.weight != length(indices)
        logs && @warn "Infeasible (No maximum matching was found)"
        return ConstraintOutput(false, changed, pruned, fixed)
    end

    # directed edges for strongly connected components
    di_ei = Vector{Int64}(undef,num_edges)
    di_ej = Vector{Int64}(undef,num_edges)

    vc = 0
    edge_counter = 0
    @inbounds for i in indices
        vc += 1
        if grid[i] != not_val
            edge_counter += 1
            di_ei[edge_counter] = vc
            di_ej[edge_counter] = vertex_mapping[grid[i]]
        else
            for pv in keys(search_space[i])
                edge_counter += 1
                if pv == pval_mapping[maximum_matching.match[vc]]
                    di_ei[edge_counter] = vc 
                    di_ej[edge_counter] = vertex_mapping[pv]
                else
                    di_ei[edge_counter] = vertex_mapping[pv]
                    di_ej[edge_counter] = vc
                end
            end
        end
    end

    sccs_map = strong_components_map(di_ei, di_ej)

    # remove the left over edges from the search space
    vmb = vertex_mapping_bw
    for (src,dst) in zip(di_ei, di_ej)
        if sccs_map[src] == sccs_map[dst]
            continue
        end
        #  remove edges in maximum matching and then edges which are part of a cycle
        if src <= length(indices) && dst == vertex_mapping[pval_mapping[maximum_matching.match[src]]]
            continue
        end

        cind = vmb[dst]
        delete!(search_space[cind], vmb[src])
        push!(pruned[cind], vmb[src])
        changed[cind] = true

        # if only one value possible make it fixed
        if length(search_space[cind]) == 1
            only_value = collect(keys(search_space[cind]))[1]
            feasible = fulfills_constraints(com, cind, only_value)
            if !feasible
                logs && @warn "The problem is infeasible"
                com.bt_infeasible[cind] += 1
                return ConstraintOutput(false, changed, pruned, fixed)
            end
            grid[cind] = only_value
            delete!(search_space, cind)
            push!(pruned[cind], grid[cind])
            changed[cind] = true
            fixed[cind] = true
        end
    end

    return ConstraintOutput(true, changed, pruned, fixed)
end

"""
    all_different(com::CoM, indices, value::Int)

Returns whether the constraint can be still fulfilled.
"""
function all_different(com::CoM, indices, value::Int)
    for i in indices
        if value == com.grid[i]
            return false
        end
    end
    return true
end
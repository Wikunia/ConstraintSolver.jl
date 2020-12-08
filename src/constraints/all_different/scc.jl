"""
    scc(di_ei, di_ej, scc_init::SCCInit)

Compute to which strongly connected component each vertex belongs.

`di_ei` and `di_ej` describe the edges such that the k-th component of di_ei and k-th component
of `di_ej` form an edge i.e `di_ei = [1, 1, 2]` and `di_ej = [3, 4, 3]` =>
  those three edges  (1, 3), (1, 4), (2, 3)

`di_ei` must be sorted asc to make this function work.

The last argument is a `SCCInit` struct which itself provides the memory for the functionality.
This speeds up the process as no new memory needs to be allocated.
"""
function scc(di_ei, di_ej, scc_init::SCCInit)
    len = length(di_ei)
    index_ei = scc_init.index_ei
    n = length(index_ei) - 1
    # compute the starting index for each vertex
    # bascially knowing where to start/end when looking for neighbors
    last = di_ei[1]
    prev_last = 1
    c = 2
    last_i = 0
    @inbounds for i in 2:len
        di_ei[i] == 0 && break
        if di_ei[i] > last
            j = last
            index_ei[(last + 1):di_ei[i]] .= c
            last = di_ei[i]
        end
        c += 1
        last_i = i
    end
    index_ei[(di_ei[last_i] + 1):end] .= c

    index_ei[1] = 1

    id = 0
    sccCount = 0

    ids = scc_init.ids
    low = scc_init.low
    on_stack = scc_init.on_stack
    group_id = scc_init.group_id

    ids .= -1
    low .= 0
    on_stack .= false
    stack = Int[]
    group_id .= 0
    c_group_id = 1

    # start dfs from each vertex if unconnected graph
    @inbounds for s in 1:n
        ids[s] != -1 && continue # if visited already continue
        dfs_work = Vector{Tuple{Int,Int}}()
        # the 0 in dfs_work represents whether it's the first time calling that vertex
        push!(dfs_work, (s, 0))
        dfs_stack = Int[]

        while !isempty(dfs_work)
            at, i = pop!(dfs_work)
            if i == 0
                on_stack[at] = true
                id += 1
                ids[at] = id
                low[at] = id
                push!(dfs_stack, at)
            end
            recurse = false
            # only works because `di_ei` is sorted
            for j in (index_ei[at] + i):(index_ei[at + 1] - 1)
                to = di_ej[j]
                # println("$to is successor of $at")
                if ids[to] == -1
                    push!(dfs_work, (at, j - index_ei[at] + 1))
                    push!(dfs_work, (to, 0))
                    recurse = true
                    break
                elseif on_stack[to]
                    low[at] = min(low[at], ids[to])
                end
            end
            recurse && continue
            # if at is the representative of the group
            if ids[at] == low[at]
                # take from stack as long as the representative doesn't appear
                # and put all of them in the same scc
                while true
                    w = pop!(dfs_stack)
                    on_stack[w] = false
                    group_id[w] = c_group_id
                    w == at && break
                end
                c_group_id += 1
            end
            if !isempty(dfs_work)
                w = at
                at, _ = dfs_work[end]
                low[at] = min(low[at], low[w])
            end
        end
    end
    return group_id
end

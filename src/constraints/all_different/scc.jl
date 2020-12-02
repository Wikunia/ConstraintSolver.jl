function scc(di_ei, di_ej)
    n = max(maximum(di_ei), maximum(di_ej))
    len = length(di_ei)
    index_ei = zeros(Int, n+1)
    last = di_ei[1]
    prev_last = 1
    c = 2
    last_i = 0
    @inbounds for i = 2:len
        di_ei[i] == 0 && break
        if di_ei[i] > last
            j = last
            index_ei[last+1:di_ei[i]] .= c
            last = di_ei[i]
        end
        c += 1
        last_i = i
    end
    index_ei[di_ei[last_i]+1:end] .= c

    index_ei[1] = 1

    id = 0
    sccCount = 0
    ids = fill(-1, n)
    low = zeros(Int, n)
    parent = zeros(Int, n)
    on_stack = zeros(Bool, n)
    stack = Int[]
    group_id = zeros(Int, n)
    c_group_id = 1

    @inbounds for s in 1:n
        ids[s] != -1 && continue # if visited already continue
        dfs_work = Vector{Tuple{Int, Int}}()
        push!(dfs_work, (s, 0))
        dfs_stack = Int[]

        while !isempty(dfs_work)
            # @show dfs_work[end]
            at,i = pop!(dfs_work)
            if i == 0
                on_stack[at] = true
                id += 1
                ids[at] = id
                low[at] = id
                push!(dfs_stack, at)
            end
            recurse = false
            # only works because `di_ei` is sorted
            for j in index_ei[at]+i:index_ei[at+1]-1
                to = di_ej[j]
                # println("$to is successor of $at")
                if ids[to] == -1
                    push!(dfs_work, (at, j-index_ei[at]+1))
                    push!(dfs_work, (to, 0))
                    recurse = true
                    break
                elseif on_stack[to]
                    low[at] = min(low[at], ids[to])
                end
            end
            recurse && continue
            if ids[at] == low[at]
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

struct BipartiteMatching
    weight :: Int64
    match  :: Vector{Int64}
end


function bipartite_cardinality_matching(l_in::Vector{Int}, r_in::Vector{Int}, m, n; l_sorted=false)
    @assert length(l_in) == length(r_in)
    @assert m <= n
    l = l_in
    r = r_in
    if !l_sorted
        perm = sortperm(l_in)
        l = l_in[perm]
        r = r_in[perm]
    end

    len = length(l)
    matching_l = zeros(Int, m)
    matching_r = zeros(Int, n)

    # create initial matching
    match_len = 0
    for (li,ri) in zip(l,r)
        if matching_l[li] == 0 && matching_r[ri] == 0
            matching_l[li] = ri
            matching_r[ri] = li
            match_len += 1
        end
    end


    if match_len < m
        # creating indices be able to get edges a vertex is connected to
        # only works if l is sorted
        index_l = zeros(Int, m+1)
        last = l[1]
        c = 2
        for i = 2:len
            if l[i] != last
                index_l[last+1] = c
                last = l[i]
            end
            c += 1
        end
        index_l[l[end]+1] = c

        index_l[1] = 1


        process_nodes = zeros(Int, m+n)
        depths = zeros(Int, m+n)
        parents = zeros(Int, m+n)
        used_l = zeros(Bool, m)
        used_r = zeros(Bool, n)
        found = false

        # find augmenting path
        while match_len < m
            pend = 1
            pstart = 1
            for li in l
                # free vertex
                if matching_l[li] == 0
                    process_nodes[pstart] = li
                    depths[pstart] = 1
                    break
                end
            end

            begin
            while pstart <= pend
                node = process_nodes[pstart]
                depth = depths[pstart]

                # from left to right
                if depth % 2 == 1
                    used_l[node] = true
                    # only works if l is sorted
                    for ri=index_l[node]:index_l[node+1]-1
                        child_node = r[ri]
                        # don't use matching edge
                        if matching_r[child_node] != node && !used_r[child_node]
                            used_r[child_node] = true
                            pend += 1
                            depths[pend] = depth+1
                            process_nodes[pend] = child_node
                            parents[pend] = pstart
                        end
                    end
                else # right to left (only matching edge)
                    # if matching edge
                    match_to = matching_r[node]
                    if match_to != 0
                        if !used_l[match_to]
                            used_l[match_to] = true
                            pend += 1
                            depths[pend] = depth+1
                            process_nodes[pend] = match_to
                            parents[pend] = pstart
                        end
                    else
                        # found augmenting path
                        parent = pstart
                        last = 0
                        c = 0
                        while parent != 0
                            current = process_nodes[parent]
                            if last != 0
                                if c % 2 == 1
                                    matching_r[last] = current
                                    matching_l[current] = last
                                end
                            end
                            c += 1
                            last = current
                            parent = parents[parent]
                        end
                        # break because we found a path
                        found = true
                        break
                    end
                end
                pstart += 1
            end
            if found
                match_len += 1
                if match_len < m
                    used_l .= false
                    used_r .= false
                end
                found = false
            else
                break
            end
            end
        end
    end
    return BipartiteMatching(match_len, matching_l)
end

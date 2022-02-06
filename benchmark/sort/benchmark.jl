function sort_element_constr(n)
    m = Model(optimizer_with_attributes(CS.Optimizer,  
        "logging" => [],
        "seed" => 4,
        "traverse_strategy" => :BFS,
    ))
    seed = 1337
    Random.seed!(seed)
    c = rand(1:1000, n)
    @variable(m, 1 <= idx[1:length(c)] <= length(c), Int)
    @variable(m, minimum(c) <= val[1:length(c)] <= maximum(c), Int)
    for i in 1:length(c)-1
        @constraint(m, val[i] <= val[i+1])
    end
    for i in 1:length(c)
        @constraint(m, c[idx[i]] == val[i])
    end
    @constraint(m, idx in CS.AllDifferent())
    optimize!(m)
end
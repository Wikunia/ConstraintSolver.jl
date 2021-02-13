function solve_str8ts(
    grid,
    white;
    backtrack = true,
    all_solutions = false,
    keep_logs = false,
    logging = [:Info, :Table],
)
    straight_tables = Vector{Array{Int,2}}(undef, 9)
    for i in 1:9
        straight_tables[i] = get_straights(collect(1:9), i)
    end

    m = Model(optimizer_with_attributes(
        CS.Optimizer,
        "backtrack" => backtrack,
        "keep_logs" => keep_logs,
        "all_solutions" => all_solutions,
        "logging" => logging,
    ))
    @variable(m, 0 <= x[1:9, 1:9] <= 9, Int)

    # set variables
    for r in 1:9, c in 1:9
        if grid[r, c] != 0
            @constraint(m, x[r, c] == grid[r, c])
        elseif white[r, c] == 1
            @constraint(m, x[r, c] >= 1)
        else # black ones without a number
            @constraint(m, x[r, c] == 0)
        end
    end

    straights = []
    for r in 1:9
        found_straight = false
        vec = Vector{Tuple{Int,Int}}()
        for c in 1:9
            if white[r, c] == 1
                found_straight = true
                push!(vec, (r, c))
            elseif found_straight
                push!(straights, copy(vec))
                empty!(vec)
                found_straight = false
            end
        end
        if found_straight
            push!(straights, copy(vec))
        end
    end

    for c in 1:9
        found_straight = false
        vec = Vector{Tuple{Int,Int}}()
        for r in 1:9
            if white[r, c] == 1
                found_straight = true
                push!(vec, (r, c))
            elseif found_straight
                push!(straights, copy(vec))
                empty!(vec)
                found_straight = false
            end
        end
        if found_straight
            push!(straights, copy(vec))
        end
    end

    for r in 1:9
        variables = [x[r, c] for c = 1:9 if white[r, c] == 1 || grid[r, c] != 0]
        @constraint(m, variables in CS.AllDifferentSet())
    end
    for c in 1:9
        variables = [x[r, c] for r = 1:9 if white[r, c] == 1 || grid[r, c] != 0]
        @constraint(m, variables in CS.AllDifferentSet())
    end

    for straight in straights
        len = length(straight)
        variables = [x[s[1], s[2]] for s in straight]
        @constraint(m, variables in CS.TableSet(straight_tables[len]))
    end

    optimize!(m)
    status = JuMP.termination_status(m)
    return status, m, x
end

function get_straights(numbers, len)
    sort!(numbers)
    nrows = (length(numbers) - len + 1) * factorial(len)
    table = Array{Int64}(undef, (nrows, len))
    i = 1
    for j in 1:(length(numbers) - len + 1)
        l = numbers[j:(j + len - 1)]
        for row in permutations(l, len)
            table[i, :] = row
            i += 1
        end
    end
    return table
end

@testset "Str8ts no backtrack" begin
    grid = zeros(Int, (9, 9))
    grid[1, :] = [0 0 0 0 0 0 0 3 0]
    grid[2, :] = [0 0 0 0 8 0 0 0 0]
    grid[3, :] = [0 0 0 0 0 0 1 0 0]
    grid[4, :] = [0 0 0 0 0 6 0 0 0]
    grid[5, :] = [0 0 1 0 0 0 0 0 8]
    grid[6, :] = [0 0 0 4 0 0 9 0 0]
    grid[7, :] = [0 0 3 5 0 0 0 0 0]
    grid[8, :] = [0 0 0 0 0 0 0 0 2]
    grid[9, :] = [5 0 9 0 0 0 0 0 0]

    white = zeros(Int, (9, 9))
    white[1, :] = [1 1 1 1 0 0 1 1 0]
    white[2, :] = [0 1 1 1 0 1 1 1 0]
    white[3, :] = [0 1 1 0 1 1 0 1 1]
    white[4, :] = [1 1 0 1 1 0 1 1 1]
    white[5, :] = [1 1 1 1 1 1 1 1 1]
    white[6, :] = [1 1 1 0 1 1 0 1 1]
    white[7, :] = [1 1 0 1 1 0 1 1 0]
    white[8, :] = [0 1 1 1 0 1 1 1 0]
    white[9, :] = [0 1 1 0 0 1 1 1 1]

    status, m, x = solve_str8ts(grid, white; all_solutions = true, logging = [])
    com = CS.get_inner_model(m)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test MOI.get(m, MOI.ResultCount()) == 1
    @test convert.(Int, JuMP.value.(x[1, :])) == [7, 9, 6, 8, 0, 0, 2, 3, 0]
    @test convert.(Int, JuMP.value.(x[2, :])) == [0, 6, 5, 7, 8, 4, 3, 2, 0]
    @test convert.(Int, JuMP.value.(x[3, :])) == [0, 3, 4, 0, 6, 5, 1, 8, 9]
    @test convert.(Int, JuMP.value.(x[4, :])) == [4, 5, 0, 2, 3, 6, 8, 9, 7]
    @test convert.(Int, JuMP.value.(x[5, :])) == [2, 4, 1, 3, 5, 9, 7, 6, 8]
    @test convert.(Int, JuMP.value.(x[6, :])) == [3, 1, 2, 4, 7, 8, 9, 5, 6]
    @test convert.(Int, JuMP.value.(x[7, :])) == [1, 2, 3, 5, 4, 0, 6, 7, 0]
    @test convert.(Int, JuMP.value.(x[8, :])) == [0, 7, 8, 6, 0, 3, 5, 4, 2]
    @test convert.(Int, JuMP.value.(x[9, :])) == [5, 8, 9, 0, 0, 2, 4, 1, 3]
end

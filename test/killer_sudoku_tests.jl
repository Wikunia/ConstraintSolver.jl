function parseKillerJSON(json_sums)
    sums = []
    for s in json_sums
        indices = Tuple[]
        for ind in s["indices"]
            push!(indices, tuple(ind...))
        end

        if haskey(s, "color")
            push!(sums, (result=s["result"], indices=indices, color=s["color"]))
        else
            push!(sums, (result=s["result"], indices=indices, color="white"))
        end
    end
    return sums
end


@testset "Killer Sudoku" begin

@testset "Killer Sudoku from wikipedia" begin
    com = CS.init()

    grid = zeros(Int, (9,9))

    com_grid = Array{CS.Variable, 2}(undef, 9, 9)
    for (ind,val) in enumerate(grid)
        com_grid[ind] = add_var!(com, 1, 9)
    end

    sums = parseKillerJSON(JSON.parsefile("data/killer_wikipedia"))

    for s in sums
        add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == s.result)
    end

    add_sudoku_constr!(com, com_grid)


    @test solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
    for s in sums
        @test s.result == sum([value(com_grid[CartesianIndex(i)]) for i in s.indices])
    end
end

@testset "Killer Sudoku niallsudoku_5500 with coefficients" begin
    com = CS.init()

    grid = zeros(Int, (9,9))

    com_grid = Array{CS.Variable, 2}(undef, 9, 9)
    for (ind,val) in enumerate(grid)
        com_grid[ind] = add_var!(com, 1, 9)
    end

    sums = parseKillerJSON(JSON.parsefile("data/killer_niallsudoku_5500"))

    # the upper left sum constraint is x+y+z = 10 and the solution is 2+1+7
    # here I change it to 5*x+7*y+z = 24
    add_constraint!(com, 5*com_grid[CartesianIndex(1,1)]+7*com_grid[CartesianIndex(2,1)]+com_grid[CartesianIndex(2,2)] == 24)

    for s in sums[2:end]
        add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == s.result)
    end

    add_sudoku_constr!(com, com_grid)


    @test solve!(com; keep_logs=true) == :Solved
    logs_1 = CS.get_logs(com)
    info_1 = com.info
    @test fulfills_sudoku_constr(com_grid)
    @test 5*value(com_grid[CartesianIndex(1,1)])+7*value(com_grid[CartesianIndex(2,1)])+value(com_grid[CartesianIndex(2,2)]) == 24
    for s in sums[2:end]
        @test s.result == sum([value(com_grid[CartesianIndex(i)]) for i in s.indices])
    end

    # test if deterministic by running it again
    com = CS.init()

    grid = zeros(Int, (9,9))

    com_grid = Array{CS.Variable, 2}(undef, 9, 9)
    for (ind,val) in enumerate(grid)
        com_grid[ind] = add_var!(com, 1, 9)
    end

    sums = parseKillerJSON(JSON.parsefile("data/killer_niallsudoku_5500"))

    # the upper left sum constraint is x+y+z = 10 and the solution is 2+1+7
    # here I change it to 5*x+7*y+z = 24
    add_constraint!(com, 5*com_grid[CartesianIndex(1,1)]+7*com_grid[CartesianIndex(2,1)]+com_grid[CartesianIndex(2,2)] == 24)

    for s in sums[2:end]
        add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == s.result)
    end

    add_sudoku_constr!(com, com_grid)

    solve!(com; keep_logs=true)
    logs_2 = CS.get_logs(com)
    info_2 = com.info
    @test info_1.pre_backtrack_calls == info_2.pre_backtrack_calls
    @test info_1.backtrack_fixes == info_2.backtrack_fixes
    @test info_1.in_backtrack_calls == info_2.in_backtrack_calls
    @test info_1.backtrack_reverses == info_2.backtrack_reverses
    @test CS.same_logs(logs_1[:tree], logs_2[:tree])
end

function killer_negative()
    com = CS.init()

    grid = zeros(Int, (9,9))

    com_grid = Array{CS.Variable, 2}(undef, 9, 9)
    for (ind,val) in enumerate(grid)
        com_grid[ind] = add_var!(com, -9, -1)
    end

    sums = parseKillerJSON(JSON.parsefile("data/killer_niallsudoku_5500"))

    # the upper left sum constraint is x+y+z = 10 and the solution is -2 + -1 + -7
    # here I change it to 5*x-7*y-z = 4
    add_constraint!(com, 5*com_grid[CartesianIndex(1,1)]-7*com_grid[CartesianIndex(2,1)]-com_grid[CartesianIndex(2,2)] == 4)

    for s in sums[2:end]
        add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == -s.result)
    end

    add_sudoku_constr!(com, com_grid)


    @test solve!(com; keep_logs=true) == :Solved
    @test fulfills_sudoku_constr(com_grid)
    @test 5*value(com_grid[CartesianIndex(1,1)])-7*value(com_grid[CartesianIndex(2,1)])-value(com_grid[CartesianIndex(2,2)]) == 4
    for s in sums[2:end]
        @test -s.result == sum([value(com_grid[CartesianIndex(i)]) for i in s.indices])
    end
    return com
end

@testset "Killer Sudoku niallsudoku_5500 with negative coefficients and -9 to -1" begin
    com1 = killer_negative()
    com2 = killer_negative()
    info_1 = com1.info
    info_2 = com2.info
    @test info_1.pre_backtrack_calls == info_2.pre_backtrack_calls
    @test info_1.backtrack_fixes == info_2.backtrack_fixes
    @test info_1.in_backtrack_calls == info_2.in_backtrack_calls
    @test info_1.backtrack_reverses == info_2.backtrack_reverses
    if info_1.in_backtrack_calls != info_2.in_backtrack_calls
        CS.save_logs(com1, "1.json")
        CS.save_logs(com2, "2.json")
        logs_1 = CS.get_logs(com1)
        logs_2 = CS.get_logs(com2)
        @test CS.same_logs(logs_1[:tree], logs_2[:tree])
    end
end

end
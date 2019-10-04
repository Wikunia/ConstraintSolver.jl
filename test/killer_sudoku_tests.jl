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
        com_grid[ind] = CS.addVar!(com, 1, 9)
    end

    sums = parseKillerJSON(JSON.parsefile("data/killer_wikipedia"))

    for s in sums
        CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == s.result)
    end

    add_sudoku_constr!(com, com_grid)


    @test CS.solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
    for s in sums
        @test s.result == sum([CS.value(com_grid[CartesianIndex(i)]) for i in s.indices])
    end
end

@testset "Killer Sudoku niallsudoku_5500 with coefficients" begin
    com = CS.init()

    grid = zeros(Int, (9,9))

    com_grid = Array{CS.Variable, 2}(undef, 9, 9)
    for (ind,val) in enumerate(grid)
        com_grid[ind] = CS.addVar!(com, 1, 9)
    end

    sums = parseKillerJSON(JSON.parsefile("data/killer_niallsudoku_5500"))

    # the upper left sum constraint is x+y+z = 10 and the solution is 2+1+7
    # here I change it to 5*x+7*y+z = 24
    CS.add_constraint!(com, 5*com_grid[CartesianIndex(1,1)]+7*com_grid[CartesianIndex(2,1)]+com_grid[CartesianIndex(2,2)] == 24)

    for s in sums[2:end]
        CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == s.result)
    end

    add_sudoku_constr!(com, com_grid)


    @test CS.solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
    @test 5*CS.value(com_grid[CartesianIndex(1,1)])+7*CS.value(com_grid[CartesianIndex(2,1)])+CS.value(com_grid[CartesianIndex(2,2)]) == 24
    for s in sums[2:end]
        @test s.result == sum([CS.value(com_grid[CartesianIndex(i)]) for i in s.indices])
    end
end

@testset "Killer Sudoku niallsudoku_5500 with negative coefficients and -9 to -1" begin
    com = CS.init()

    grid = zeros(Int, (9,9))

    com_grid = Array{CS.Variable, 2}(undef, 9, 9)
    for (ind,val) in enumerate(grid)
        com_grid[ind] = CS.addVar!(com, -9, -1)
    end

    sums = parseKillerJSON(JSON.parsefile("data/killer_niallsudoku_5500"))

    # the upper left sum constraint is x+y+z = 10 and the solution is -2 + -1 + -7
    # here I change it to 5*x-7*y-z = 4
    CS.add_constraint!(com, 5*com_grid[CartesianIndex(1,1)]-7*com_grid[CartesianIndex(2,1)]-com_grid[CartesianIndex(2,2)] == 4)

    for s in sums[2:end]
        CS.add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == -s.result)
    end

    add_sudoku_constr!(com, com_grid)


    @test CS.solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
    @test 5*CS.value(com_grid[CartesianIndex(1,1)])-7*CS.value(com_grid[CartesianIndex(2,1)])-CS.value(com_grid[CartesianIndex(2,2)]) == 4
    for s in sums[2:end]
        @test -s.result == sum([CS.value(com_grid[CartesianIndex(i)]) for i in s.indices])
    end
end

end
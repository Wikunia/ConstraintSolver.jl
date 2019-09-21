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
        CS.add_constraint!(com, CS.eq_sum, [com_grid[CartesianIndex(ind)] for ind in s.indices]; rhs=s.result)
    end

    add_sudoku_constr!(com, com_grid)


    @test CS.solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
    for s in sums
        @test s.result == sum([CS.value(com_grid[CartesianIndex(i)]) for i in s.indices])
    end
end
end
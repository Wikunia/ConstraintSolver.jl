@testset "Sudoku" begin

@testset "Sudoku from opensourc.es" begin
    com = CS.init()

    grid = zeros(Int, (9,9))
    grid[1,:] = [0,2,1,0,7,9,0,8,5]
    grid[2,:] = [0,4,5,3,1,0,0,0,9]
    grid[3,:] = [0,7,0,0,4,0,0,1,0]
    grid[4,:] = [0,0,0,1,0,8,0,3,6]
    grid[5,:] = [0,6,0,0,0,0,2,0,8]
    grid[6,:] = [0,0,0,0,0,3,0,0,4]
    grid[7,:] = [6,0,8,0,0,0,0,0,0]
    grid[8,:] = [0,9,4,0,0,7,8,0,0]
    grid[9,:] = [2,0,0,5,0,0,0,4,0]

    com_grid = create_sudoku_grid!(com, grid)
    add_sudoku_constr!(com, com_grid)

    @test CS.solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
end


@testset "Hard sudoku" begin
    com = CS.init()

    grid = zeros(Int,(9,9))
    grid[1,:] = [0 0 0 5 4 6 0 0 9]
    grid[2,:] = [0 2 0 0 0 0 0 0 7]
    grid[3,:] = [0 0 3 9 0 0 0 0 4]
    grid[4,:] = [9 0 5 0 0 0 0 7 0]
    grid[5,:] = [7 0 0 0 0 0 0 2 0]
    grid[6,:] = [0 0 0 0 9 3 0 0 0]
    grid[7,:] = [0 5 6 0 0 8 0 0 0]
    grid[8,:] = [0 1 0 0 3 9 0 0 0]
    grid[9,:] = [0 0 0 0 0 0 8 0 6]

    com_grid = create_sudoku_grid!(com, grid)
    add_sudoku_constr!(com, com_grid)

    @test CS.solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
end

@testset "Hard sudoku infeasible" begin
    com = CS.init()

    grid = zeros(Int,(9,9))
    grid[1,:] = [0 0 0 5 4 6 0 0 9]
    grid[2,:] = [0 2 0 0 0 0 0 0 7]
    grid[3,:] = [0 0 3 9 0 0 0 0 4]
    grid[4,:] = [9 0 5 0 0 0 0 7 3]
    grid[5,:] = [7 0 0 0 0 0 0 2 0]
    grid[6,:] = [0 0 0 0 9 3 0 0 0]
    grid[7,:] = [0 5 6 0 0 8 0 0 0]
    grid[8,:] = [0 1 0 0 3 9 0 0 0]
    grid[9,:] = [0 0 0 0 0 0 8 0 6]

    com_grid = create_sudoku_grid!(com, grid)
    add_sudoku_constr!(com, com_grid)

    @test CS.solve!(com) == :Infeasible
    @test !fulfills_sudoku_constr(com_grid)
end


@testset "Hard fsudoku repo" begin
    com = CS.init()

    grid = zeros(Int,(9,9))
    grid[1,:] = [0 0 0 0 0 0 0 0 0]
    grid[2,:] = [0 1 0 6 2 0 0 9 0]
    grid[3,:] = [0 0 2 0 0 9 3 1 0]
    grid[4,:] = [0 0 4 0 0 6 0 8 0]
    grid[5,:] = [0 0 8 7 0 2 1 0 0]
    grid[6,:] = [0 3 0 8 0 0 5 0 0]
    grid[7,:] = [0 6 9 1 0 0 4 0 0]
    grid[8,:] = [0 8 0 0 7 3 0 5 0]
    grid[9,:] = [0 0 0 0 0 0 0 0 0]

    com_grid = create_sudoku_grid!(com, grid)
    add_sudoku_constr!(com, com_grid)

    @test CS.solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
end

@testset "Hard fsudoku repo 0-8" begin
    com = CS.init()

    grid = zeros(Int,(9,9))
    grid[1,:] = [0 0 0 0 0 0 0 0 0]
    grid[2,:] = [0 1 0 6 2 0 0 9 0]
    grid[3,:] = [0 0 2 0 0 9 3 1 0]
    grid[4,:] = [0 0 4 0 0 6 0 8 0]
    grid[5,:] = [0 0 8 7 0 2 1 0 0]
    grid[6,:] = [0 3 0 8 0 0 5 0 0]
    grid[7,:] = [0 6 9 1 0 0 4 0 0]
    grid[8,:] = [0 8 0 0 7 3 0 5 0]
    grid[9,:] = [0 0 0 0 0 0 0 0 0]
    grid .-= 1

    com_grid = Array{CS.Variable, 2}(undef, 9, 9)
    for (ind,val) in enumerate(grid)
        if val == -1
            if ind == 81 # bottom right
                # some other values are possible there
                com_grid[ind] = CS.addVar!(com, 9, 11)
            elseif ind == 80 # one above (will be 9 in the end)
                com_grid[ind] = CS.addVar!(com, 7, 11)
            else
                com_grid[ind] = CS.addVar!(com, 0, 8)
            end
        else
            com_grid[ind] = CS.addVar!(com, 0, 8; fix=val)
        end
    end
    
    add_sudoku_constr!(com, com_grid)

    @test CS.solve!(com) == :Solved
    @test fulfills_sudoku_constr(com_grid)
end

@testset "top95 some use backtracking" begin
    grids = sudokus_from_file("data/top95")
    c = 0
    for grid in grids
        com = CS.init()

        com_grid = create_sudoku_grid!(com, grid)
        add_sudoku_constr!(com, com_grid)

        @test CS.solve!(com) == :Solved
        @test fulfills_sudoku_constr(com_grid)
        c += 1
    end
    # check that actually all 95 problems were tested
    @test c == 95
end


@testset "Number 7 in top95.txt w/o backtracking" begin
    com = CS.init()

    grid = Int[6,0,2,0,5,0,0,0,0,0,0,0,0,0,3,0,4,0,0,0,0,0,0,0,0,0,0,4,3,0,0,0,8,0,
              0,0,0,1,0,0,0,0,2,0,0,0,0,0,0,0,0,7,0,0,5,0,0,2,7,0,0,0,0,0,0,0,0,0,
              0,0,8,1,0,0,0,6,0,0,0,0,0]
    grid = transpose(reshape(grid, (9,9)))

    com_grid = create_sudoku_grid!(com, grid)
    add_sudoku_constr!(com, com_grid)

    CS.solve!(com; backtrack=false)
    @test !com.info.backtracked
    @test com.info.backtrack_fixes == 0
    @test com.info.in_backtrack_calls == 0
    @show com.info
end


end
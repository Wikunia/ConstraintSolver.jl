@testset "Sudoku" begin

@testset "Sudoku from opensourc.es" begin
    com = CS.init()

    grid = zeros(Int8, (9,9))
    grid[1,:] = [0,2,1,0,7,9,0,8,5]
    grid[2,:] = [0,4,5,3,1,0,0,0,9]
    grid[3,:] = [0,7,0,0,4,0,0,1,0]
    grid[4,:] = [0,0,0,1,0,8,0,3,6]
    grid[5,:] = [0,6,0,0,0,0,2,0,8]
    grid[6,:] = [0,0,0,0,0,3,0,0,4]
    grid[7,:] = [6,0,8,0,0,0,0,0,0]
    grid[8,:] = [0,9,4,0,0,7,8,0,0]
    grid[9,:] = [2,0,0,5,0,0,0,4,0]

    CS.build_search_space(com, grid,[1,2,3,4,5,6,7,8,9],0)
    add_sudoku_constr!(com, grid)

    @test CS.solve(com) == :Solved
    @test fulfills_sudoku_constr(com)
end

@testset "Hard Sudoku no backtrack" begin
    com = CS.init()

    grid = zeros(Int8, (9,9))
    grid[1,:] = [0 0 0 5 4 6 0 0 9]
    grid[2,:] = [0 2 0 0 0 0 0 0 7]
    grid[3,:] = [0 0 3 9 0 0 0 0 4]
    grid[4,:] = [9 0 5 0 0 0 0 7 0]
    grid[5,:] = [7 0 0 0 0 0 0 2 0]
    grid[6,:] = [0 0 0 0 9 3 0 0 0]
    grid[7,:] = [0 5 6 0 0 8 0 0 0]
    grid[8,:] = [0 1 0 0 3 9 0 0 0]
    grid[9,:] = [0 0 0 0 0 0 8 0 6]

    CS.build_search_space(com, grid,[1,2,3,4,5,6,7,8,9],0)
    add_sudoku_constr!(com, grid)

    CS.solve(com; backtrack=false)
    CS.print_search_space(com; max_length=12)
end

@testset "Hard sudoku" begin
    com = CS.init()

    grid = zeros(Int8,(9,9))
    grid[1,:] = [0 0 0 5 4 6 0 0 9]
    grid[2,:] = [0 2 0 0 0 0 0 0 7]
    grid[3,:] = [0 0 3 9 0 0 0 0 4]
    grid[4,:] = [9 0 5 0 0 0 0 7 0]
    grid[5,:] = [7 0 0 0 0 0 0 2 0]
    grid[6,:] = [0 0 0 0 9 3 0 0 0]
    grid[7,:] = [0 5 6 0 0 8 0 0 0]
    grid[8,:] = [0 1 0 0 3 9 0 0 0]
    grid[9,:] = [0 0 0 0 0 0 8 0 6]

    CS.build_search_space(com, grid,[1,2,3,4,5,6,7,8,9],0)
    add_sudoku_constr!(com, grid)

    @test CS.solve(com) == :Solved
    @test fulfills_sudoku_constr(com)
end

@testset "Hard sudoku infeasible" begin
    com = CS.init()

    grid = zeros(Int8,(9,9))
    grid[1,:] = [0 0 0 5 4 6 0 0 9]
    grid[2,:] = [0 2 0 0 0 0 0 0 7]
    grid[3,:] = [0 0 3 9 0 0 0 0 4]
    grid[4,:] = [9 0 5 0 0 0 0 7 3]
    grid[5,:] = [7 0 0 0 0 0 0 2 0]
    grid[6,:] = [0 0 0 0 9 3 0 0 0]
    grid[7,:] = [0 5 6 0 0 8 0 0 0]
    grid[8,:] = [0 1 0 0 3 9 0 0 0]
    grid[9,:] = [0 0 0 0 0 0 8 0 6]

    CS.build_search_space(com, grid,[1,2,3,4,5,6,7,8,9],0)
    add_sudoku_constr!(com, grid)

    @test CS.solve(com) == :Infeasible
    @test !fulfills_sudoku_constr(com)
end


@testset "Hard fsudoku repo" begin
    com = CS.init()

    grid = zeros(Int8,(9,9))
    grid[1,:] = [0 0 0 0 0 0 0 0 0]
    grid[2,:] = [0 1 0 6 2 0 0 9 0]
    grid[3,:] = [0 0 2 0 0 9 3 1 0]
    grid[4,:] = [0 0 4 0 0 6 0 8 0]
    grid[5,:] = [0 0 8 7 0 2 1 0 0]
    grid[6,:] = [0 3 0 8 0 0 5 0 0]
    grid[7,:] = [0 6 9 1 0 0 4 0 0]
    grid[8,:] = [0 8 0 0 7 3 0 5 0]
    grid[9,:] = [0 0 0 0 0 0 0 0 0]

    CS.build_search_space(com, grid,[1,2,3,4,5,6,7,8,9],0)
    add_sudoku_constr!(com, grid)

    @test CS.solve(com) == :Solved
    @test fulfills_sudoku_constr(com)
end

@testset "Hard fsudoku repo 0-8" begin
    com = CS.init()

    grid = zeros(Int8,(9,9))
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

    CS.build_search_space(com, grid,[0,1,2,3,4,5,6,7,8],-1)
    add_sudoku_constr!(com, grid)

    @test CS.solve(com) == :Solved
    @test fulfills_sudoku_constr(com)
end

@testset "Hard fsudoku repo 42-58 sudoku" begin
    com = CS.init()

    grid = zeros(Int8,(9,9))
    grid[1,:] = [0 0 0 0 0 0 0 0 0]
    grid[2,:] = [0 1 0 6 2 0 0 9 0]
    grid[3,:] = [0 0 2 0 0 9 3 1 0]
    grid[4,:] = [0 0 4 0 0 6 0 8 0]
    grid[5,:] = [0 0 8 7 0 2 1 0 0]
    grid[6,:] = [0 3 0 8 0 0 5 0 0]
    grid[7,:] = [0 6 9 1 0 0 4 0 0]
    grid[8,:] = [0 8 0 0 7 3 0 5 0]
    grid[9,:] = [0 0 0 0 0 0 0 0 0]
    grid .+= 20
    grid .*= 2

    CS.build_search_space(com, grid,[42,44,46,48,50,52,54,56,58],40)
    add_sudoku_constr!(com, grid)

    @test CS.solve(com) == :Solved
    @test fulfills_sudoku_constr(com)
end


end
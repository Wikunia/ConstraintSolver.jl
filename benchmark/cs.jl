using ConstraintSolver

CS = ConstraintSolver
include("../test/sudoku_fcts.jl")

function from_file(filename, sep='\n')
    s = open(filename) do file
        read(file, String)
    end
    str_sudokus = split(strip(s), sep)
    grids = AbstractArray[]
    for str_sudoku in str_sudokus
        str_sudoku = replace(str_sudoku, "."=>"0")
        one_line_grid = parse.(Int8, split(str_sudoku,""))
        grid = reshape(one_line_grid, 9, 9)
        push!(grids, grid)
    end
    return grids
end

function solve_all(grids, name)
    t = time()
    grids = grids
    for (i,grid) in enumerate(grids)
        com = CS.init()

        CS.build_search_space!(com, grid,[1,2,3,4,5,6,7,8,9],0)
        add_sudoku_constr!(com, grid)

        t = time()
        status = CS.solve!(com);
        t = time()-t
        println(i-1,", ", t)
        # @show com.info
        # println("Status: ", status)
        # CS.print_search_space(com)
        # @assert fulfills_sudoku_constr(com)
    end
    tt = time()-t
    println("total time: ", tt)
    println("avg: ", tt/length(grids))
end

function main()
    solve_all(from_file("benchmark/top95.txt"), "hard")
    # solve_all(from_file("hardest.txt"), "hardest")
end

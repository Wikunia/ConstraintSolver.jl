using ConstraintSolver

CS = ConstraintSolver
include("../../test/sudoku_fcts.jl")

function from_file(filename, sep='\n')
    s = open(filename) do file
        read(file, String)
    end
    str_sudokus = split(strip(s), sep)
    grids = AbstractArray[]
    for str_sudoku in str_sudokus
        str_sudoku = replace(str_sudoku, "."=>"0")
        one_line_grid = parse.(Int, split(str_sudoku,""))
        grid = reshape(one_line_grid, 9, 9)
        push!(grids, grid)
    end
    return grids
end

function solve_all(grids; benchmark=false, single_times=true)
    ct = time()
    grids = grids
    for (i,grid) in enumerate(grids)
        com = CS.init()

        com_grid = create_sudoku_grid!(com, grid)
        add_sudoku_constr!(com, com_grid)

        if single_times
            GC.enable(false)
            t = time()
            status = solve!(com);
            t = time()-t
            GC.enable(true)
            println(i-1,", ", t)
        else
            GC.enable(false)
            status = solve!(com);
            GC.enable(true)
        end
        if !benchmark
            @show com.info
            println("Status: ", status)
            @assert fulfills_sudoku_constr(com_grid)
        end
    end
    println("")
    tt = time()-ct
    println("total time: ", tt)
    println("avg: ", tt/length(grids))
end

function solve_one(grid)
    com = CS.init()

    CS.build_search_space!(com, grid,[1,2,3,4,5,6,7,8,9],0)
    add_sudoku_constr!(com, grid)

    status = solve!(com; backtrack=false);
    return com
end

function main(; benchmark=false, single_times=true)
    solve_all(from_file("benchmark/sudoku/data/top95.txt"); benchmark=benchmark, single_times=single_times)
    # solve_all(from_file("hardest.txt"), "hardest")
end


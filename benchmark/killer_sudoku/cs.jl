using ConstraintSolver
using JSON

CS = ConstraintSolver
include("../../test/sudoku_fcts.jl")

function parseJSON(json_sums)
    sums = []
    for s in json_sums
        indices = Tuple[]
        for ind in s["indices"]
            push!(indices, tuple(ind...))
        end

        push!(sums, (result=s["result"], indices=indices))
    end
    return sums
end

function solve_all(filenames; benchmark=false, single_times=true)
    ct = time()
    for (i,filename) in enumerate(filenames)
        sums = parseJSON(JSON.parsefile("data/$(filename)"))

        com = CS.init()
        grid = zeros(Int, (9,9))

        com_grid = create_sudoku_grid!(com, grid)

        for s in sums
            add_constraint!(com, sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == s.result)
            # add_constraint!(com, CS.all_different([com_grid[CartesianIndex(ind)] for ind in s.indices]))
        end

        add_sudoku_constr!(com, com_grid)

        if single_times
            GC.enable(false)
            t = time()
            status = solve!(com; keep_logs=true);
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
    println("avg: ", tt/length(filenames))
end

function main(; benchmark=false, single_times=true)
    solve_all(["niallsudoku_5500", "niallsudoku_5501", "niallsudoku_5502", "niallsudoku_5503"]; benchmark=benchmark, single_times=single_times)
    # solve_all(from_file("hardest.txt"), "hardest")
end


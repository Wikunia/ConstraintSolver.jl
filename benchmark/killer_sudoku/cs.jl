using JuMP
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
        sums = parseJSON(JSON.parsefile("./benchmark/killer_sudoku/data/$(filename)"))

        m = Model(with_optimizer(CS.Optimizer))
        @variable(m, 1 <= x[1:9,1:9] <= 9, Int)

        for s in sums
            @constraint(m, sum([x[ind...] for ind in s.indices]) == s.result)
            # @constraint(m, [x[ind...] for ind in s.indices] in CS.AllDifferentSet(length(s.indices)))
        end

        # sudoku constraints
        jump_add_sudoku_constr!(m, x)

        if single_times
            GC.enable(false)
            t = time()
            optimize!(m)
            status = JuMP.termination_status(m)
            t = time()-t
            GC.enable(true)
            println(i-1,", ", t)
        else
            GC.enable(false)
            optimize!(m)
            status = JuMP.termination_status(m)
            GC.enable(true)
        end
        if !benchmark
            @show JuMP.backend(m).optimizer.model.inner.info
            println("Status: ", status)
            @assert jump_fulfills_sudoku_constr(JuMP.value.(x))
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


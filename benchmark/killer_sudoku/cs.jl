using ConstraintSolver, MathOptInterface, JSON

if !@isdefined CS 
    const CS = ConstraintSolver
end
const MOI = MathOptInterface
const MOIU = MOI.Utilities
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

        m = CS.Optimizer()
        
        x = [[MOI.add_constrained_variable(m, MOI.Integer()) for i=1:9] for j=1:9]
        for r=1:9, c=1:9
            MOI.add_constraint(m, x[r][c][1], MOI.GreaterThan(1.0))
            MOI.add_constraint(m, x[r][c][1], MOI.LessThan(9.0))
        end

        for s in sums
            saf = MOI.ScalarAffineFunction{Float64}([MOI.ScalarAffineTerm(1.0, x[ind[1]][ind[2]][1]) for ind in s.indices], 0.0)
            MOI.add_constraint(m, saf, MOI.EqualTo(convert(Float64,s.result)))
            # @constraint(m, [x[ind...] for ind in s.indices] in CS.AllDifferentSet(length(s.indices)))
        end

        # sudoku constraints
        moi_add_sudoku_constr!(m, x)

        if single_times
            GC.enable(false)
            t = time()
            MOI.optimize!(m)
            status = MOI.get(m, MOI.TerminationStatus())
            t = time()-t
            GC.enable(true)
            println(i-1,", ", t)
        else
            GC.enable(false)
            MOI.optimize!(m)
            status = MOI.get(m, MOI.TerminationStatus())
            GC.enable(true)
        end
        if !benchmark
            @show m.inner.info
            println("Status: ", status)
            solution = zeros(Int, 9, 9)
            for r=1:9
                solution[r,:] = [MOI.get(m, MOI.VariablePrimal(), x[r][c][1]) for c=1:9]
            end
            @assert jump_fulfills_sudoku_constr(solution)
        end
        com = nothing
        GC.gc()
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


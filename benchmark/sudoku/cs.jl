using ConstraintSolver, JuMP, MathOptInterface

if !@isdefined CS
    const CS = ConstraintSolver
end
const MOI = MathOptInterface
const MOIU = MOI.Utilities
include("../../test/sudoku_fcts.jl")

function from_file(filename, sep = '\n')
    s = open(filename) do file
        read(file, String)
    end
    str_sudokus = split(strip(s), sep)
    grids = AbstractArray[]
    for str_sudoku in str_sudokus
        str_sudoku = replace(str_sudoku, "." => "0")
        one_line_grid = parse.(Int, split(str_sudoku, ""))
        grid = reshape(one_line_grid, 9, 9)
        push!(grids, grid)
    end
    return grids
end

function solve_all(grids; benchmark = false, single_times = true)
    ct = time()
    grids = grids
    for (i, grid) in enumerate(grids)
        m = CS.Optimizer(logging = [])

        x = [[MOI.add_constrained_variable(m, MOI.Integer()) for i in 1:9] for j in 1:9]
        for r in 1:9, c in 1:9
            MOI.add_constraint(m, x[r][c][1], MOI.GreaterThan(1.0))
            MOI.add_constraint(m, x[r][c][1], MOI.LessThan(9.0))
        end

        # set variables
        for r in 1:9, c in 1:9
            if grid[r, c] != 0
                sat = [MOI.ScalarAffineTerm(1.0, x[r][c][1])]
                MOI.add_constraint(
                    m,
                    MOI.ScalarAffineFunction{Float64}(sat, 0.0),
                    MOI.EqualTo(convert(Float64, grid[r, c])),
                )
            end
        end
        # sudoku constraints
        moi_add_sudoku_constr!(m, x)

        if single_times
            GC.enable(false)
            MOI.optimize!(m)
            status = MOI.get(m, MOI.TerminationStatus())
            GC.enable(true)
            # println(i - 1, ", ", MOI.get(m, MOI.SolveTimeSec()))
        else
            GC.enable(false)
            MOI.optimize!(m)
            status = MOI.get(m, MOI.TerminationStatus())
            GC.enable(true)
        end
        if !benchmark
            println("Status: ", status)
            solution = zeros(Int, 9, 9)
            for r in 1:9
                solution[r, :] = [MOI.get(m, MOI.VariablePrimal(), x[r][c][1]) for c in 1:9]
            end
            @assert jump_fulfills_sudoku_constr(solution)
        end
    end
    # println("")
    tt = time() - ct
    # println("total time: ", tt)
    # println("avg: ", tt / length(grids))
end

function main(; benchmark = false, single_times = true)
    solve_all(
        from_file("data/top95.txt");
        benchmark = benchmark,
        single_times = single_times,
    )
    # solve_all(from_file("hardest.txt"), "hardest")
end

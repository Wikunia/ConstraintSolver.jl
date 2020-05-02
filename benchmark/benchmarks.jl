using BenchmarkTools
using ConstraintSolver, JuMP, MathOptInterface

const CS = ConstraintSolver
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const SUITE = BenchmarkGroup()

dir = pkgdir(ConstraintSolver)
include(joinpath(dir, "benchmark/sudoku/benchmark.jl"))

SUITE["sudoku"] = BenchmarkGroup(["alldifferent"])
sudoku_grids = from_file(joinpath(dir, "benchmark/sudoku/data/top95.txt"))
for i=1:5:95
    SUITE["sudoku"]["top95_$i"] = @benchmarkable solve_sudoku($sudoku_grids[$i]) seconds=2
end

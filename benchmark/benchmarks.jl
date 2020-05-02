using BenchmarkTools
using ConstraintSolver, JuMP, MathOptInterface

const CS = ConstraintSolver
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const SUITE = BenchmarkGroup()

dir = pkgdir(ConstraintSolver)
include(joinpath(dir, "benchmark/sudoku/benchmark.jl"))

SUITE["sudoku"] = BenchmarkGroup(["alldifferent"])
benchmark_sudoku!(SUITE["sudoku"], from_file(joinpath(dir, "benchmark/sudoku/data/top95.txt")))

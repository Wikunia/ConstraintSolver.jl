using BenchmarkTools
using ConstraintSolver, JuMP, MathOptInterface
using GLPK, JSON, Cbc

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

include(joinpath(dir, "benchmark/eternity/benchmark.jl"))

SUITE["eternity"] = BenchmarkGroup(["alldifferent", "table", "equal"])
# compiling run 
solve_eternity("eternity_6x5"; height=6, width=5)
SUITE["eternity"]["6x5"] = @benchmarkable solve_eternity("eternity_6x5"; height=6, width=5) seconds=30
SUITE["eternity"]["6x5"] = @benchmarkable solve_eternity("eternity_6x5"; height=6, width=5, optimize=true) seconds=30
SUITE["eternity"]["6x5"] = @benchmarkable solve_eternity("eternity_6x5"; height=6, width=5, optimize=true, indicator=true) seconds=30
SUITE["eternity"]["5x5_all"] = @benchmarkable solve_eternity("eternity_5x5"; all_solutions=true) seconds=30

include(joinpath(dir, "benchmark/lp/benchmark.jl"))

SUITE["lp"] = BenchmarkGroup(["objective", "less_than"])
# compiling run
solve_lp()
SUITE["lp"]["issue_83"] = @benchmarkable solve_lp() seconds=2

include(joinpath(dir, "benchmark/killer_sudoku/benchmark.jl"))

SUITE["killer_sudoku"] = BenchmarkGroup(["alldifferent", "equal"])
# compiling run
solve_killer_sudoku("niallsudoku_5500")
SUITE["killer_sudoku"]["niall_5500"] = @benchmarkable solve_killer_sudoku("niallsudoku_5500") seconds=5
SUITE["killer_sudoku"]["niall_5501"] = @benchmarkable solve_killer_sudoku("niallsudoku_5501") seconds=5
SUITE["killer_sudoku"]["niall_5500_special"] = @benchmarkable solve_killer_sudoku("niallsudoku_5500"; special=true) seconds=15
SUITE["killer_sudoku"]["niall_5501_special"] = @benchmarkable solve_killer_sudoku("niallsudoku_5501"; special=true) seconds=15

include(joinpath(dir, "benchmark/graph_color/benchmark.jl"))

SUITE["graph_coloring"] = BenchmarkGroup(["notequal", "equal", "svc"])
# compiling run
solve_us_graph_coloring()
SUITE["graph_coloring"]["US_8+equal"] = @benchmarkable solve_us_graph_coloring(;num_colors=8, equality=true) seconds=5
SUITE["graph_coloring"]["US_50colors+equal"] = @benchmarkable solve_us_graph_coloring(;num_colors=50, equality=true) seconds=5
SUITE["graph_coloring"]["US_50colors"] = @benchmarkable solve_us_graph_coloring(;num_colors=50, equality=false) seconds=5
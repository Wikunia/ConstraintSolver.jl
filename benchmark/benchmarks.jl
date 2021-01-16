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
for i in 1:5:95
    SUITE["sudoku"]["top95_$i"] = @benchmarkable solve_sudoku($sudoku_grids[$i]) seconds = 2
end

include(joinpath(dir, "benchmark/eternity/benchmark.jl"))

SUITE["eternity"] = BenchmarkGroup(["alldifferent", "table", "equal"])
# compiling run
solve_eternity("eternity_6x5"; height = 6, width = 5)
SUITE["eternity"]["6x5"] =
    @benchmarkable solve_eternity("eternity_6x5"; height = 6, width = 5) seconds = 30
SUITE["eternity"]["6x5_ABS"] =
    @benchmarkable solve_eternity("eternity_6x5"; height = 6, width = 5, branch_strategy=:ABS) seconds = 30
SUITE["eternity"]["5x5_opt"] =
    @benchmarkable solve_eternity("eternity_5x5"; height = 5, width = 5, optimize = true) seconds =
        120
SUITE["eternity"]["5x5_opt_ind"] = @benchmarkable solve_eternity(
    "eternity_5x5";
    height = 5,
    width = 5,
    optimize = true,
    indicator = true,
) seconds = 120
SUITE["eternity"]["5x5_opt_rei"] = @benchmarkable solve_eternity(
    "eternity_5x5";
    height = 5,
    width = 5,
    optimize = true,
    reified = true,
) seconds = 120
SUITE["eternity"]["5x5_all"] =
    @benchmarkable solve_eternity("eternity_5x5"; all_solutions = true) seconds = 30

include(joinpath(dir, "benchmark/lp/benchmark.jl"))

SUITE["lp"] = BenchmarkGroup(["objective", "less_than"])
# compiling run
solve_lp()
SUITE["lp"]["issue_83"] = @benchmarkable solve_lp() seconds = 2

include(joinpath(dir, "benchmark/killer_sudoku/benchmark.jl"))

SUITE["killer_sudoku"] = BenchmarkGroup(["alldifferent", "equal"])
# compiling run
solve_killer_sudoku("niallsudoku_5500")
SUITE["killer_sudoku"]["niall_5500"] =
    @benchmarkable solve_killer_sudoku("niallsudoku_5500") seconds = 5
SUITE["killer_sudoku"]["niall_5501"] =
    @benchmarkable solve_killer_sudoku("niallsudoku_5501") seconds = 5
SUITE["killer_sudoku"]["niall_5500_ABS"] =
    @benchmarkable solve_killer_sudoku("niallsudoku_5500"; branch_strategy=:ABS) seconds = 5
SUITE["killer_sudoku"]["niall_5501_ABS"] =
    @benchmarkable solve_killer_sudoku("niallsudoku_5501"; branch_strategy=:ABS) seconds = 5
SUITE["killer_sudoku"]["niall_5500_special"] =
    @benchmarkable solve_killer_sudoku("niallsudoku_5500"; special = true) seconds = 15
SUITE["killer_sudoku"]["niall_5501_special"] =
    @benchmarkable solve_killer_sudoku("niallsudoku_5501"; special = true) seconds = 15

include(joinpath(dir, "benchmark/graph_color/benchmark.jl"))

SUITE["graph_coloring"] = BenchmarkGroup(["notequal", "equal", "svc"])
# compiling run
solve_us_graph_coloring()
SUITE["graph_coloring"]["US_8+equal"] =
    @benchmarkable solve_us_graph_coloring(; num_colors = 8, equality = true) seconds = 5
SUITE["graph_coloring"]["US_50colors+equal"] =
    @benchmarkable solve_us_graph_coloring(; num_colors = 50, equality = true) seconds = 5
SUITE["graph_coloring"]["US_8+equal_ABS"] =
    @benchmarkable solve_us_graph_coloring(; num_colors = 8, equality = true, branch_strategy=:ABS) seconds = 5
SUITE["graph_coloring"]["US_50colors+equal_ABS"] =
    @benchmarkable solve_us_graph_coloring(; num_colors = 50, equality = true, branch_strategy=:ABS) seconds = 5
SUITE["graph_coloring"]["US_50colors"] =
    @benchmarkable solve_us_graph_coloring(; num_colors = 50, equality = false) seconds = 5
SUITE["graph_coloring"]["queen7_7"] =
    @benchmarkable color_graph(joinpath(dir, "benchmark/graph_color/data/queen7_7.col"), 7) seconds =
        10
SUITE["graph_coloring"]["le450_5d"] =
    @benchmarkable color_graph(joinpath(dir, "benchmark/graph_color/data/le450_5d.col"), 5) seconds =
        30


include(joinpath(dir, "benchmark/scheduling/benchmark.jl"))

SUITE["scheduling"] = BenchmarkGroup(["cumulative", "equal", "less_than"])
# compiling run
furniture_moving()
SUITE["scheduling"]["furniture_moving"] =
    @benchmarkable furniture_moving() seconds = 5


# Problem instance
organize_day_problem = Dict(

    #task id     1      2      3      4
    :tasks => ["Work","Mail","Shop","Bank"],

    # duration of the four tasks
    :durations => [4,1,2,1],

    # precedences
    # [A,B] : task A must be completed before task B
    :precedences => [
                        4 3;
                        2 1
                    ],
    # Time limits
    :start_time => 9,
    :end_time => 17
)

SUITE["scheduling"]["organize_day"] =
    @benchmarkable organize_day(organize_day_problem) seconds = 5

using Test
using ConstraintSolver
using JSON

CS = ConstraintSolver

include("fct_tests.jl")

include("sudoku_fcts.jl")
include("small_special_tests.jl")
include("sudoku_tests.jl")
include("killer_sudoku_tests.jl")
include("graph_color_tests.jl")
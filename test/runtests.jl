using Test
using ConstraintSolver
using JSON
using MathOptInterface, JuMP

const MOI = MathOptInterface
const CS = ConstraintSolver

include("fct_tests.jl")
include("moi.jl")

include("sudoku_fcts.jl")
include("small_special_tests.jl")
include("small_eq_sum_real.jl")
include("sudoku_tests.jl")
include("killer_sudoku_tests.jl")
include("graph_color_tests.jl")
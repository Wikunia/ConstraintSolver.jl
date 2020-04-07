![Build status](https://github.com/Wikunia/ConstraintSolver.jl/workflows/Run%20tests/badge.svg) [![codecov](https://codecov.io/gh/Wikunia/ConstraintSolver.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Wikunia/ConstraintSolver.jl)
[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://wikunia.github.io/ConstraintSolver.jl/dev)

# ConstraintSolver.jl

This package aims to be a constraint solver written in Julia and will be documented completely on my blog [OpenSourc.es](https://opensourc.es/blog/constraint-solver-1)

## Goals
- Easily extendable
- Teaching/Learning about constraint programming

## Installation
You can install this julia package using 
`] add ConstraintSolver` or if you want to change code you might want to use
`] dev ConstraintSolver`. 

## Example

You can easily use this package using the same modelling package as you might be used to for solving (non)linear problems in Julia: [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl).

### Sudoku
```
using JuMP

grid = [6 0 2 0 5 0 0 0 0;
        0 0 0 0 0 3 0 4 0;
        0 0 0 0 0 0 0 0 0;
        4 3 0 0 0 8 0 0 0;
        0 1 0 0 0 0 2 0 0;
        0 0 0 0 0 0 7 0 0;
        5 0 0 2 7 0 0 0 0;
        0 0 0 0 0 0 0 8 1;
        0 0 0 6 0 0 0 0 0]

using ConstraintSolver
const CS = ConstraintSolver

# creating a constraint solver model and setting ConstraintSolver as the optimizer.
m = Model(CS.Optimizer) 
# define the 81 variables
@variable(m, 1 <= x[1:9,1:9] <= 9, Int)
# set variables if fixed
for r=1:9, c=1:9
    if grid[r,c] != 0
        @constraint(m, x[r,c] == grid[r,c])
    end
end

for rc = 1:9
    @constraint(m, x[rc,:] in CS.AllDifferentSet())
    @constraint(m, x[:,rc] in CS.AllDifferentSet())
end

for br=0:2
    for bc=0:2
        @constraint(m, vec(x[br*3+1:(br+1)*3,bc*3+1:(bc+1)*3]) in CS.AllDifferentSet())
    end
end

optimize!(m)

# retrieve grid
grid = convert.(Int, JuMP.value.(x))
```

## Supported variables and constraints
You can see a list of currently supported constraints [in the docs](https://wikunia.github.io/ConstraintSolver.jl/dev/supported.html).
This constraint solver works only with bounded discrete variables.


## Blog posts
- [Setup of the solver and basic backtracking for Sudoku](https://opensourc.es/blog/constraint-solver-1)
- [Pruning in Sudoku](https://opensourc.es/blog/constraint-solver-pruning)
- [More pruning and benchmarks](https://opensourc.es/blog/constraint-solver-pruning-benchmarking)
- [Sophisticated implementation of the alldifferent constraint and benchmarks](https://opensourc.es/blog/constraint-solver-alldifferent)
- [New data structure for better user interface and performance](https://opensourc.es/blog/constraint-solver-data-structure)
- [Backtrack without recursion and start of sum constraint](https://opensourc.es/blog/constraint-solver-backtrack-sum)
- [Speed up the sum constraint](https://opensourc.es/blog/constraint-solver-sum-speed)
- [UI changes and refactoring](https://opensourc.es/blog/constraint-solver-ui-refactor)
- [Recap video](https://opensourc.es/blog/constraint-solver-first-recap)
- [First step in graph coloring](https://opensourc.es/blog/constraint-solver-simple-graph-coloring)
- [Comarison with MIP using graph coloring](https://opensourc.es/blog/constraint-solver-mip-graph-coloring)
- [Documentation with Documenter.jl and newest Benchmarking results](https://opensourc.es/blog/constraint-solver-docs-and-benchmarks)
- [How to profile Julia code](https://opensourc.es/blog/constraint-solver-profiling)
- [Second take on bipartite matchings](https://opensourc.es/blog/constraint-solver-bipartite-matching)
- [Making it a JuMP solver](https://opensourc.es/blog/constraint-solver-jump)
- [Dealing with real objectives](https://opensourc.es/blog/constraint-solver-floats)
- [Support for linear objectives](https://opensourc.es/blog/constraint-solver-linear-objective)
- [Table logging](https://opensourc.es/blog/table-logging)
- [Bound computation](https://opensourc.es/blog/constraint-solver-bounds)

## Notice
I'm a MSc student in computer science so I don't have much knowledge on how constraint programming works but I'm keen to find out ;)

## Support
If you find a bug or improvement please open an issue or make a pull request. 
You just enjoy reading and want to see more posts and get them earlier? Support me on [Patreon](https://www.patreon.com/opensources) or click on the support button at the top of this website. ;)

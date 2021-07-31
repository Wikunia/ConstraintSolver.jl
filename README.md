![Build status](https://github.com/Wikunia/ConstraintSolver.jl/workflows/Run%20tests/badge.svg) [![codecov](https://codecov.io/gh/Wikunia/ConstraintSolver.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Wikunia/ConstraintSolver.jl)
[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://wikunia.github.io/ConstraintSolver.jl/dev)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://wikunia.github.io/ConstraintSolver.jl/stable)

# ConstraintSolver.jl

![Logo](https://user-images.githubusercontent.com/4931746/83681097-2c247480-a5e2-11ea-9301-0c46726dea25.png)

This package aims to be a constraint solver completely written in Julia. The concepts are more or less fully described on my blog [OpenSourc.es](https://opensourc.es/blog/constraint-solver-1).
There is of course also the general user manual [here](https://wikunia.github.io/ConstraintSolver.jl/stable) which explains how to solve your model.


## Goals
- Easily extendable
- Teaching/Learning about constraint programming

## Installation
You can install this julia package using 
`] add ConstraintSolver` or if you want to change code you might want to use
`] dev ConstraintSolver`. 

## Example

You can easily use this package with the same modeling package as you might be used to for solving (non)linear problems in Julia: [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl).

### Sudoku
```julia
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
# define a shorter name ;)
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
    @constraint(m, x[rc,:] in CS.AllDifferent())
    @constraint(m, x[:,rc] in CS.AllDifferent())
end

for br=0:2
    for bc=0:2
        @constraint(m, vec(x[br*3+1:(br+1)*3,bc*3+1:(bc+1)*3]) in CS.AllDifferent())
    end
end

optimize!(m)

# retrieve grid
grid = convert.(Int, JuMP.value.(x))
```

## Supported variables and constraints
You can see a list of currently supported constraints [in the docs](https://wikunia.github.io/ConstraintSolver.jl/stable/supported/).
In general the solver works only with bounded discrete variables and supports these constraints
- linear constraints
- all different
- table
- indictoar
- reified
- boolean

## Examples

A list of example problems can be found on the website by [Håkan Kjellerstrand](http://hakank.org/julia/constraints/).


## Blog posts
If you're interested in how the solver works you can checkout my blog [opensourc.es](https://opensourc.es). There are currently around 30 blog posts about the constraint solver and a new one is added about once per month.

## Notice
I'm a MSc student in computer science so I don't have much knowledge on how constraint programming works but I'm keen to find out ;)

## Support
If you find a bug or improvement please open an issue or make a pull request. 
Additionally if you use the solver regularly or are interested in further development please checkout my [Patreon](https://www.patreon.com/opensources) page or click on the support button at the top of this website. ;)

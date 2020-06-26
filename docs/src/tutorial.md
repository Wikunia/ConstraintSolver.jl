# Tutorial

This is a series of tutorials to solve basic problems using the constraint solver.

Before we tackle some problems we first have to install the constraint solver.

```
$ julia
] add ConstraintSolver.jl
```

Then we have to use the package with:

```
using ConstraintSolver
const CS = ConstraintSolver
```

additionally we need to include the modelling package [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl) with:

```
using JuMP
```

Solving:
  - [Sudoku](#Sudoku-1)
  - [Graph coloring](#Graph-coloring-1)
  - [Better bound computation](#Bound-computation-1)

## Sudoku

Everybody knows sudokus and for some it might be fun to solve them by hand. Today we want to use
this constraint solver to let the computer do the hard work.

Rules of sudoku:
  - We have 9x9 grid each cell contains a digit or is empty initially
  - We have nine 3x3 blocks 
  - In the end we want to fill the grid such that
    - Each row, column and block should have the digits 1-9 exactly once
  
We now have to translate this into code:

Defining the grid:
```
grid = [6 0 2 0 5 0 0 0 0;
        0 0 0 0 0 3 0 4 0;
        0 0 0 0 0 0 0 0 0;
        4 3 0 0 0 8 0 0 0;
        0 1 0 0 0 0 2 0 0;
        0 0 0 0 0 0 7 0 0;
        5 0 0 2 7 0 0 0 0;
        0 0 0 0 0 0 0 8 1;
        0 0 0 6 0 0 0 0 0]
```

`0` represents an empty cell. Then we need a variable for each cell:

```
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
```

For the empty cell we create a variable with possible values `1-9` and otherwise we do the same but fix the value to the given cell value.

Then we define the constraints:

```
for rc = 1:9
    @constraint(m, x[rc,:] in CS.AllDifferentSet())
    @constraint(m, x[:,rc] in CS.AllDifferentSet())
end
```

For each row and column (1-9) we create an `AllDifferent` constraint which specifies that all the variables should have a different value in the end using `CS.AllDifferentSet()`.
As there are always nine variables and nine digits each value 1-9 is set exactly once per row and column.

Now we need to add the constraints for the 3x3 blocks:

```
for br=0:2
    for bc=0:2
        @constraint(m, vec(x[br*3+1:(br+1)*3,bc*3+1:(bc+1)*3]) in CS.AllDifferentSet())
    end
end
```

Then we call the solve function of JuMP called `optimize` with the model as the only parameter.

```
optimize!(m)
```
**Attention:** This might take a while for the first solve as everything needs to be compiled but the second time it will be fast.

The status of the model can be extracted by:

```
status = JuMP.termination_status(m)
```

This returns a [MOI](https://github.com/JuliaOpt/MathOptInterface.jl) StatusCode which are explained [here](http://www.juliaopt.org/JuMP.jl/v0.19.2/solutions/#MathOptInterface.TerminationStatusCode).

In our case it returns `MOI.OPTIMAL`. If we want to get the solved sudoku we can use:

```
@show convert.(Integer,JuMP.value.(x))
```

which outputs:
```
6  8  2  1  5  4  3  7  9
9  5  1  7  6  3  8  4  2
3  7  4  8  9  2  1  6  5
4  3  7  5  2  8  9  1  6
8  1  6  9  3  7  2  5  4
2  9  5  4  1  6  7  3  8
5  6  8  2  7  1  4  9  3
7  2  9  3  4  5  6  8  1
1  4  3  6  8  9  5  2  7
```

If you want to get a single value you can i.e use `JuMP.value(com_grid[1])`.

In the next part you'll learn a different constraint type and how to include an optimization function.

## Graph coloring

The goal is to color a graph in such a way that neighboring nodes have a different color. This can also be used to color a map.

We want to find the coloring which uses the least amount of colors.

```
m = Model(CS.Optimizer)
num_colors = 10

@variable(m, 1 <= countries[1:5] <= num_colors, Int)
germany, switzerland, france, italy, spain = countries
```

I know this is only a small example but you can easily extend it.
In the above case we assume that we don't need more than 10 colors.

Adding the constraints:

```
@constraint(m, germany != france)
@constraint(m, germany != switzerland)
@constraint(m, france != spain)
@constraint(m, france != switzerland)
@constraint(m, france != italy)
@constraint(m, switzerland != italy)
```

If we call `optimize!(m)` now we probably don't get a coloring with the least amount of colors.

We can get this by adding:

```
@variable(m, 1 <= max_color <= num_colors, Int)
@constraint(m, max_color .>= countries)
@objective(m, Min, max_color)
optimize!(m)
status = JuMP.termination_status(m)
```

We can get the value for each variable using `JuMP.value(germany)` for example or as before print the values:

```
println(JuMP.value.(countries))
```

and getting the maximum color used with 

```
println("#colors: $(JuMP.value(max_color))")
```

# Bound computation

In this section you learn how to combine the alldifferent constraint and a sum constraint as well as using an objective function.
When using a linear objective function it is useful to get good bounds to find the optimal solution faster and proof optimality.
There is a very very basic bound computation build into the ConstraintSolver itself by just having a look at the maximum and minium values per variable.
However this is a very bad estimate most of the time i.e for less than constraints.

If we have
```
m = Model(CS.Optimizer) 
@variable(m, 0 <= x[1:10] <= 15, Int)
@constraint(m, sum(x) <=  15)
@objective(m, Max, sum(x))
```

Each variable itself can have all values but the objective bound is of course $15$ and not $150$. Instead of building this directly into the ConstraintSolver I decided 
to instead get help by a linear solver of your choice.
You can use this with the option `lp_optimizer`:

```
cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
m = Model(optimizer_with_attributes(
    CS.Optimizer,
    "lp_optimizer" => cbc_optimizer,
))
@variable(m, 0 <= x[1:10] <= 15, Int)
@constraint(m, sum(x) <=  15)
@objective(m, Max, sum(x))
optimize!(m)
```

It creates an `LP` with all supported constraints so `<=, >=, ==`. The ConstraintSolver will then work as the branch and bound part to solve the discrete problem.
This is currently slower for problems that you can formulate directly as a MIP as the one above but now you can solve problems like:

```
cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
m = Model(optimizer_with_attributes(
    CS.Optimizer,
    "lp_optimizer" => cbc_optimizer,
))
@variable(m, 0 <= x[1:10] <= 15, Int)
@constraint(m, sum(x) >= 10)
@constraint(m, x[1:5] in CS.AllDifferentSet())
@constraint(m, x[6:10] in CS.AllDifferentSet())
@objective(m, Min, sum(x))
optimize!(m)
```


# Tutorial

This is a series of tutorials to solve basic problems using the constraint solver.

Before we tackle some problems we first have to install the constraint solver.

```
$ julia
] add https://github.com/Wikunia/ConstraintSolver.jl
```

The package is currently not an official package which is the reason why we need to specify the url here.

Then we have to use the package with:

```
using ConstraintSolver
CS = ConstraintSolver
```

Solving:
  - [Sudoku](#Sudoku-1)
  - [Graph coloring](#Graph-coloring-1)

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
com = CS.init() # creating a constraint solver model
com_grid = Array{CS.Variable, 2}(undef, 9, 9)
for (ind,val) in enumerate(grid)
    if val == 0
        com_grid[ind] = add_var!(com, 1, 9)
    else
        com_grid[ind] = add_var!(com, 1, 9; fix=val)
    end
end
```

For the empty cell we create a variable with possible values `1-9` and otherwise we do the same but fix the value to the given cell value.

Then we define the constraints:

```
for rc=1:9
    #row
    variables = com_grid[CartesianIndices((rc:rc,1:9))]
    add_constraint!(com, CS.all_different([variables...]))
    #col
    variables = com_grid[CartesianIndices((1:9,rc:rc))]
    add_constraint!(com, CS.all_different([variables...]))
end
```

For each row and column (1-9) we extract the variables from `com_grid` and create an `all_different` constraint which specifies that all the variables should have a different value in the end. As there are always nine variables and nine digits we have an exactly once constraint as we want given the rules of sudoku.

The variables have to be one dimensional so we use `...` at the end to flatten the 2D array.

Adding the constraints for the 3x3 blocks:

```
for br=0:2
    for bc=0:2
        variables = com_grid[CartesianIndices((br*3+1:(br+1)*3,bc*3+1:(bc+1)*3))]
        add_constraint!(com, CS.all_different([variables...]))
    end
end
```

Then we call the solve function with the `com` model as the only parameter.

```
status = solve!(com)
```

This returns a status `:Solved` or `:Infeasible` if there is no solution.

In our case it returns `:Solved`. If we want to get the solved sudoku we can use:

```
println(com_grid)
```

which outputs:
```
6 9 3 4 8 2 5 7 1 
8 5 7 3 1 9 6 2 4 
2 1 4 7 6 5 8 9 3 
1 7 8 5 9 4 2 3 6 
5 6 9 2 3 1 7 4 8 
4 3 2 8 7 6 1 5 9 
3 8 1 9 2 7 4 6 5 
7 4 6 1 5 3 9 8 2 
9 2 5 6 4 8 3 1 7 
```

If you want to get a single value you can i.e use `value(com_grid[1])`.

In the next part you'll learn a different constraint type and how to include an optimization function.

## Graph coloring

The goal is to color a graph in such a way that neighboring nodes have a different color. This can also be used to color a map.

We want to find the coloring which uses the least amount of colors.

```
com = CS.init()

germany = add_var!(com, 1, 10)
france = add_var!(com, 1, 10)
spain = add_var!(com, 1, 10)
switzerland = add_var!(com, 1, 10)
italy = add_var!(com, 1, 10)

countries = [germany, switzerland, france, italy, spain];
```

I know this is only a small example but you can easily extend it.
In the above case we assume that we don't need more than 10 colors.

Adding the constraints:

```
add_constraint!(com, germany != france)
add_constraint!(com, germany != switzerland)
add_constraint!(com, france != spain)
add_constraint!(com, france != switzerland)
add_constraint!(com, france != italy)
add_constraint!(com, switzerland != italy)
```

If we call `status = solve!(com)` now we probably don't get a coloring with the least amount of colors.

We can get this using:

```
set_objective!(com, :Min, CS.vars_max(countries))
status = solve!(com)
```

We can get the value for each variable using `value(germany)` for example or as before print the values:

```
println(countries)
```

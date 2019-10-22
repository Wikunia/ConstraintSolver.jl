# How-To Guide

It seems like you have some specific questions about how to use the constraint solver.

## How to create a simple model?

```
using ConstraintSolver
CS = ConstraintSolver

com = CS.init()

x = add_var!(com, 1, 9)
y = add_var!(com, 1, 5)

add_constraint!(com, x + y == 14)

status = solve!(com)
```

## How to add a uniqueness/all_different constraint?

If you want that the values are all different for some variables you can use:

```
add_constraint!(com, CS.all_different(vars))
```

where `vars` is an array of variables of the constraint solver i.e `[x,y]`.


## How to add an optimization function / objective?

Besides specifying the model you need to specify whether it's a minimization `:Min` or maximization `:Max` objective.
```
set_objective!(com, :Min, CS.vars_max(vars))
```

Currently the only objective is `CS.vars_max(vars)` which represents the maximum value of all variables. 

More will come in the future ;)

## How to get the solution?

If you define your variables `x,y` like shown in the [simple model example](#how-to-create-a-simple-model-1) you can get the value
after solving with:

```
val_x = value(x)
val_y = value(y)
```

## How to get the state before backtracking?

For the explanation of the question look [here](../explanation.html/#Backtracking-1).

Instead of solving the model directly you can have a look at the state before backtracking with:

```
status = solve!(com; backtrack=false)
```

and then check the variables using `CS.values(x)` or `CS.values(y)` this returns an array of possible values.





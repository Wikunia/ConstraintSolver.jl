# How-To Guide

It seems like you have some specific questions about how to use the constraint solver.

## How to create a simple model?

```
using JuMP, ConstraintSolver
const CS = ConstraintSolver

m = Model(with_optimizer(CS.Optimizer)) 
@variable(m, 1 <= x <= 9, Int)
@variable(m, 1 <= y <= 5, Int)

@constraint(m, x + y == 14)

optimize!(m)
status = JuMP.termination_status(m)
```

## How to add a uniqueness/all_different constraint?

If you want that the values are all different for some variables you can use:

```
@constraint(m, vars in CS.AllDifferentSet(length(vars)))
```

where `vars` is an array of variables of the constraint solver i.e `[x,y]`.


## How to add an optimization function / objective?

Besides specifying the model you need to specify whether it's a minimization `Min` or maximization `Max` objective.

```
@objective(m, Min, x)
```

Currently the only objective is to minimize or maximize a single variable.

More will come in the future ;)

## How to get the solution?

If you define your variables `x,y` like shown in the [simple model example](#how-to-create-a-simple-model-1) you can get the value
after solving with:

```
val_x = JuMP.value(x)
val_y = JuMP.value(y)
```

or:

```
val_x, val_y = JuMP.value.([x,y])
```

## How to get the state before backtracking?

For the explanation of the question look [here](explanation.html#Backtracking-1).

Instead of solving the model directly you can have a look at the state before backtracking by setting an option of the ConstraintSolver:

```
m = Model(with_optimizer(CS.Optimizer, backtrack=false))
```

and then check the variables using `CS.values(m, x)` or `CS.values(m, y)` this returns an array of possible values.





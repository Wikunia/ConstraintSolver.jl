# How-To Guide

It seems like you have some specific questions about how to use the constraint solver.

## How to create a simple model?

```
using JuMP, ConstraintSolver
const CS = ConstraintSolver

m = Model(CS.Optimizer) 
@variable(m, 1 <= x <= 9, Int)
@variable(m, 1 <= y <= 5, Int)

@constraint(m, x + y == 14)

optimize!(m)
status = JuMP.termination_status(m)
```

## How to add a uniqueness/all_different constraint?

If you want that the values are all different for some variables you can use:

```
@constraint(m, vars in CS.AllDifferentSet()
```

where `vars` is an array of variables of the constraint solver i.e `[x,y]`.


## How to add an optimization function / objective?

Besides specifying the model you need to specify whether it's a minimization `Min` or maximization `Max` objective.

```
@objective(m, Min, x)
```
or for linear functions you would have something like:
```
@variable(m, x[1:4], Bin)
weights = [0.2, -0.1, 0.4, -0.8]
@objective(m, Min, sum(weights.*x))
```

Currently the only objective is to minimize or maximize a single variable or linear function.

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
m = Model(optimizer_with_attributes(CS.Optimizer, "backtrack"=>false))
```

and then check the variables using `CS.values(m, x)` or `CS.values(m, y)` this returns an array of possible values.


## How to improve the bound computation?

You might have encountered that the bound computation is not good. If you haven't already you should check out the tutorial on bound computation.
It is definitely advised that you use an LP solver for computing bounds. 

## How to define variables by a set of integers?

Instead of `@variable(m, 1 <= x <= 10, Int)` and then remove values with `@constraint(m, x != 3)`.
You can directly write:

```
@variable(m, CS.Integers([i for i=1:10 if i != 3]))
```

this removes unnecessary constraints. 

## How to define a set of possibilities for more than one variable?

In some cases it is useful to define that some variables can only have a fixed number of combinations
together which can't be easily specified by any other constraint.

Then you can use the table constraint.

```
cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
model = Model(optimizer_with_attributes(
    CS.Optimizer,
    "lp_optimizer" => cbc_optimizer,
))

# Variables
@variable(model, 1 <= x[1:5] <= 5, Int)

#=
    Specify that only the following 5 options are possible.
    First row means:
    x[1] = 1, x[2] = 2, x[3] = 3, x[4] = 1, x[5] = 1 is one possible combination.
    The last row shows that when x[1] = 4 all other variables are fixed as well.
    For x[1]={2,3} there is no solution
=#
table = [
    1 2 3 1 1;
    1 3 3 2 1;
    1 1 3 2 1;
    1 1 1 2 4;
    4 5 5 3 4;
]

@constraint(model, x in CS.TableSet(table))

@objective(model, Max, sum(x))
optimize!(model)
```

Table constraints can represent a lot of constraints including alldifferent but it's always reasonable to use
one of the other constraints if it directly represents the problem.
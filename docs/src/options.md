# Solver options

This documentation lists all solver options and the default value in `()`

In general these options can be set as follows if you're using JuMP:

```
m = Model(optimizer_with_attributes(CS.Optimizer, "option_name"=>option_value))
```

## `logging` (`[:Info, :Table]`)

Current possible symbols
- :Info
    - Shows info about how many variables are part of the model
    - Info about which constraints are present in the model
- :Table
    - Shows a table about the current solver status

Output will be something like
```
# Variables: 5
# Constraints: 2
 - # Inequality: 2

   #Open      #Closed         Incumbent             Best Bound        Time [s]  
================================================================================
     2           0                -                   44.20            0.0003  
```
  
## `table` (`TableSetup(...)`)

Defines the exact table setup. The actual default is:

```
TableSetup(
        [:open_nodes, :closed_nodes, :incumbent, :best_bound, :duration],
        ["#Open", "#Closed", "Incumbent", "Best Bound", "[s]"],
        [10,10,20,20,10]; 
        min_diff_duration=5.0
)
```

which means that the open/closed nodes, the incumbent and the best bound is shown besides the duration of the optimization process. 
- `[10,10,20,20,10]` gives the width of each column
- `min_diff_duration=5.0` => a new row is added every 5 seconds or if a new solution was found.

For satisfiability problems the incumbent and best bound are `0` so you could remove them. I'll probably add that ;)

## `rtol` (`1e-6`)

Defines the relative tolerance of the solver.

## `atol` (`1e-6`)

Defines the absolute tolerance of the solver.

## `lp_optimizer` (`nothing`)

It is advised to use a linear problem solver like [Cbc.jl](https://github.com/JuliaOpt/Cbc.jl) if you have a lot of linear constraints and an optimization problem. The solver is used to compute bounds in the optimization steps.

## `all_solutions` (`false`)

You can set this to `true` to get **all feasible** solutions. This can be used to get all solutions for a sudoku for example but maybe shouldn't be used for an optimization problem. Nevertheless I leave it here so you be able to use it even for optimization problems and get all feasible solutions.

Look at `all_optimal_solutions` if you only want all solutions with the same optimum.

## `all_optimal_solutions` (`false`)

You can set this to `true` to get **optimal solutions**. If you have a feasibility problem you can also use `all_solutions` but for optimization problems this will only return solutions with the same best incumbent.


## `backtrack` (`true`)

To solve the problem completely normally backtracking needs to be used but for some problems like certain sudokus this might not be necessary. This option is mostly there for debugging reasons to check the search space before backtracking starts.

## `max_bt_steps` (`typemax(Int)`)

You can set the maximum amount of backtracking steps with this option. Probably you only want to change this if you want to debug some stuff.

## `backtrack_sorting` (`true`)

If set to true the order of new nodes is determined by their best bound. Otherwise they will be traversed in order they were added to the stack.

## `keep_logs` (`false`)

Sometimes you might be interested in the exact way the problem got solved then you can set this option to `true` to get the full search tree.

To save the logs as a json file you need to run:

```
m = Model()
...
com = JuMP.backend(m).optimizer.model.inner

CS.save_logs(com, "FILENAME.json")
```

## `solution_type` (`Float64`)

Defines the type of `best_bound` and `incumbent`. Normally you don't want to change this as JuMP only works with `Float` but if you work directly using MathOptInterface you can use this option.


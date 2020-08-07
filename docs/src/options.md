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

## `time_limit` (`Inf`)

Time limit for backtracking in seconds. If reached before the problem was solved or infeasibility was proven will return the status `MOI.TIME_LIMIT`.

## `rtol` (`1e-6`)

Defines the relative tolerance of the solver.

## `atol` (`1e-6`)

Defines the absolute tolerance of the solver.

## `lp_optimizer` (`nothing`)

It is advised to use a linear problem solver like [Cbc.jl](https://github.com/JuliaOpt/Cbc.jl) if you have a lot of linear constraints and an optimization problem. The solver is used to compute bounds in the optimization steps.

## `traverse_strategy` (`:Auto`)

You can chose a traversal strategy for you model with this option. The default is choosing depending on the model. In feasibility problems depth first search is chosen and in optimization problems best first search.
Other options:
- `:BFS` => Best First Search
- `:DFS` => Depth First Search
- `:DBFS` => Depth First Search until solution was found then Best First Search

## `branch_strategy` (`:Auto`)

You can chose a branch strategy for you model with this option. Currently the only one is [Activity Based Search](https://arxiv.org/pdf/1105.6314.pdf)
It is based on that paper but currently does not fully implement all the details. For further options see `activity_decay`

Other options:
- `:ABS` => Activity based search

## `activity_decay` (0.999)

The activity of variables decays when they are not used in the current node. In the following it is written as $\gamma$.

$X$ are the variables and $X^{\prime}$ denotes variables that have been changed. $D(x)$ is the domain of the variable $x$ and 
$A(x)$ is the activity.

$$
\begin{aligned}
\forall x \in X & \text { s.t. } |D(x)| > 1: A(x) = A(x) \cdot \gamma \\
\forall x \in X^{\prime} &: A(x)=A(x)+1
\end{aligned}
$$

## `branch_split` (`:Auto`)

You can define how the variable is split into two branches with this option. 
Normally the smallest value is chosen for satisfiability problems and depending on the coefficient of the variable in the objective either the smallest or biggest is chosen as a single choice for optimization problems.
Other options:
- `:Smallest` Smallest value on the left branch and rest on the right branch
- `:Biggest` same as smallest but splits into biggest value as a single choice and the rest the second choice
- `:InHalf` takes the mean value to split the problem into two branches of equal size

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

Additionally because the mapping from JuMP can be different to your internal mapping you can use:

```
CS.save_logs(com, "FILENAME.json", :x => x)
```
if `x` is/are your variable/variables and if you have more variables:

```
CS.save_logs(com, "FILENAME.json", :x => x, :y => y)
```
etc...

## `solution_type` (`Float64`)

Defines the type of `best_bound` and `incumbent`. Normally you don't want to change this as JuMP only works with `Float` but if you work directly using MathOptInterface you can use this option.


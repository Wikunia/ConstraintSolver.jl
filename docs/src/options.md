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

## `seed` (`1`)

Some parts of the constraint solver use random numbers. Nevertheless everything should be reproducable which is the default case. You can make it "truly" random by setting a random `seed`.

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

You can chose a branch strategy for you model with this option.

**Options:**
- `:IMPS` => Infeasible and Minimum Possibility Search
  - This is currently the automatic default
  - Chooses the next variable based on 
    - whether the variable is part of the objective function
    - an infeasibility counter for each variable
    - the number of open possibilities
- `:ABS` => [Activity Based Search](https://arxiv.org/pdf/1105.6314.pdf)
  - It is based on that paper but doesn't implement value selection. For further options see `activity`


## `activity` 

The following options can be set with `activity.` i.e `"activity.decay" => 0.9`. These options are only taken into consideration when the `branch_strategy` option is set to `:ABS`

### `decay` (0.999)

The activity of variables decays when they are not used in the current node. In the following it is written as $\gamma$.
$X$ are the variables and $X^{\prime}$ denotes variables that have been changed. 
$D(x)$ is the domain of the variable $x$ and 
$A(x)$ is the activity.

```math
\begin{aligned}
\forall x \in X& \text { s.t. } |D(x)| > 1 &: A(x) = A(x) \cdot \gamma \\
\forall x \in X^{\prime}& &: A(x)=A(x)+1
\end{aligned}
```

### `max_probes` (`10`)

When activity based search is selected the search space gets probed by using a random variable selection strategy to initialize the activity of each variable.

The probing can be stopped by either hitting `max_probes` or when one can be confident to a certain degree that the approximated activity is good enough. (see `max_confidence_deviation`)

### `max_confidence_deviation` (`20`)

Probing as explained in `max_probes` can be stopped when each variable has an approximated activity when is in a specified bound. The bound can be changed using this option.

More precisely probing is stopped when this range
```math
\left[\tilde{\mu_{A}}(x)-t_{0.05, n-1} \cdot \frac{\tilde{\sigma_{A}}(x)}{\sqrt{n}}, \tilde{\mu_{A}}(x)+t_{0.05, n-1} \cdot \frac{\tilde{\sigma_{A}}(x)}{\sqrt{n}}\right]
```

is within $\pm$ `max_confidence_deviation` % of the empirical mean.

## `branch_split` (`:Auto`)

You can define how the variable is split into two branches with this option. 
Normally the smallest value is chosen for satisfiability problems and depending on the coefficient of the variable in the objective either the smallest or biggest is chosen as a single choice for optimization problems.
Other options:
- `:Smallest` Smallest value on the left branch and rest on the right branch
- `:Biggest` same as smallest but splits into biggest value as a single choice and the rest the second choice
- `:InHalf` takes the mean value to split the problem into two branches of equal size

## `simplify` (`True`)

Defines whether the solver should spend some time and effort to simplify constraints.
Curently this works for the following:
- combining `!=` constraints to all different constraints
- combining `sum(x) == V` overlapping all different constraints to introduce more constraints
- combining `x .>= y` constraints to a `GeqSet` constraint which helps with bound computation

It can be turned off to not waste time if this isn't applicable or not wanted for whatever reason.

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
com = CS.get_inner_model(m)

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
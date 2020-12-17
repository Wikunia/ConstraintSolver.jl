# Supported variables, constraints and objectives

This solver is in a pre-release phase right now and not a lot of constraints or objectives are supported.
If you want to be up to date you might want to check this page every couple of months. 

You can also watch the project to be informed of every change but this might spam you ;)

## Supported objectives

Currently the only objective supported is the linear objective i.e

```
@objective(m, Min, 2x+3y)
```

## Supported variables

All variables need to be bounded and discrete. 

```
@variable(m, x) # does not work
@variable(m, x, Int) # doesn't work because it isn't bounded
@variable(m, x, Bin) # does work because it is discrete and bounded
@variable(m, 1 <= x, Int) # doesn't work because it isn't bounded from above
@variable(m, 1 <= x <= 7, Int) # does work
```

Additionally you can specify a set of allowed integers:

```
@variable(m, x, CS.Integers([1,3,5,7]))
```

### Anonymous variables

Besides the named way of defining variables it's also possible to have anonymous variables as provided by [JuMP.jl](https://github.com/jump-dev/JuMP.jl). 

This can be useful when one needs to create temporary variables for reformulations of the problem. The values of these variables can't be easily accessed later on but they avoid the problem of needing a new name for all temporary variables.

The general usage is described in the [JuMP docs](https://jump.dev/JuMP.jl/stable/variables/#Anonymous-JuMP-variables-1) but the following gives an idea on how to use them for the most common use-cases in combination with ConstraintSolver.jl .

```julia
# create an anonymous array of 5 integer variables with the domain [0,2,3,4,5]
x = @variable(model, [1:5], variable_type=CS.Integers([0,2,3,4,5]))
# create a single anonymous binary variable 
b = @variable(model, binary=true)
# create a single anonymous integer variable **Important:** Needs bounds
y = @variable(model, integer=true, lower_bound=0, upper_bound=10)
```

### Missing
- Interval variables for scheduling

## Supported constraints

The following list shows constraints that are implemented and those which are planned.

- [X] Linear constraints
  - At the moment this is kind of partially supported as they are not really good at giving bounds yet
  - [X] `==`
  - [X] `<=`
  - [X] `>=`
  - [X] `!=`
- [X] All different
  - `@constraint(m, [x,y,z] in CS.AllDifferentSet())`
- [X] `TableSet` constraint [#130](https://github.com/Wikunia/ConstraintSolver.jl/pull/130)
- Indicator constraints [#167](https://github.com/Wikunia/ConstraintSolver.jl/pull/167)
  - i.e `@constraint(m, b => {x + y >= 12})`
  - [X] for affine inner constraints
  - [X] for all types of inner constraints
- Reified constraints [#171](https://github.com/Wikunia/ConstraintSolver.jl/pull/171)
  - i.e `@constraint(m, b := {x + y >= 12})`
  - [X] for affine inner constraints
  - [X] for all types of inner constraints
- Element constraints
  - [ ] 1D array with constant values 
    - i.e `T = [12,87,42,1337]` `T[y] == z` with `y` and `z` being variables [#213](https://github.com/Wikunia/ConstraintSolver.jl/pull/213)
  - [ ] 2D array with constant values 
    - where T is an array
  - [ ] 1D array with variables
    - where T is a vector of variables 
- [ ] Allowing `&&` and `||` in indicator and reified constraints
- [ ] Scheduling constraints
- [ ] Cycle constraints

If I miss something which would be helpful for your needs please open an issue.

## Additionally 
- [ ] adding new constraints after `optimize!` got called [#72](https://github.com/Wikunia/ConstraintSolver.jl/issues/72)

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

### Missing
- Interval variables for scheduling

## Supported constraints

It's a bit more but still not as fully featured as I would like it to be.

- [X] Linear constraints
  - At the moment this is kind of partially supported as they are not really good at giving bounds yet
  - [X] `==`
  - [X] `<=`
  - [X] `>=`
  - [X] `!=`
- [X] All different
  - `@constraint(m, [x,y,z] in CS.AllDifferentSet())`
- [X] `TableSet` constraint [#130](https://github.com/Wikunia/ConstraintSolver.jl/pull/130)
- [X] Indicator constraints [#167](https://github.com/Wikunia/ConstraintSolver.jl/pull/167)
  - i.e `@constraint(m, b => {x + y >= 12})`
  - [X] for affine inner constraints
  - [X] for all types of inner constraints
- [ ] Scheduling constraints
- [ ] Cycle constraints

If I miss something which would be helpful for your needs please open an issue.

## Additionally 
- [ ] adding new constraints after `optimize!` got called [#72](https://github.com/Wikunia/ConstraintSolver.jl/issues/72)

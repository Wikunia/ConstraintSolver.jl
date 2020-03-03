# Supported constraints and objectives

This solver is in a pre-release phase right now and not a lot of constraints or objectives are supported.
If you want to be up to date you might want to check this page every couple of months. 

You can also watch the project to be informed of every change but this might spam you ;)

## Supported objectives

Currently the only objective supported is the linear objective i.e

```
@objective(m, Min, 2x+3y)
```

## Supported constraints

It's a bit more but still not as fully featured as I would like it to be.

- [X] Linear constraints
  - At the moment this is kind of partially supported as they are not really good at giving bounds yet
  - [X] `==`
  - [X] `<=`
  - [X] `>=`
- [X] All different
  - `@constraint(m, x[1:9] in CS.AllDifferentSet(9))`
  - Currently you have to specify the length of vector
- [ ] Support for `!=`
  - [X] Supports `a != b` with `a` and `b` being single variables
  - [ ] Support for linear unequal constraints [#66](https://github.com/Wikunia/ConstraintSolver.jl/issues/66)
- [ ] Cycle constraints

If I miss something which would be helpful for your needs please open an issue.

## Additionally 
- [ ] adding new constraints after `optimize!` got called [#72](https://github.com/Wikunia/ConstraintSolver.jl/issues/72)

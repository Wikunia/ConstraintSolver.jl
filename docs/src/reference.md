# Reference

## User interface functions

```@docs
ConstraintSolver.init
add_var!
add_constraint!
set_objective!
solve!
ConstraintSolver.value
```

### Constraints

These can be used as constraints for a model

```@docs
ConstraintSolver.all_different(variables::Vector{ConstraintSolver.Variable})
Base.:(==)(x::ConstraintSolver.LinearVariables, y::Int)
Base.:(==)(x::ConstraintSolver.LinearVariables, y::ConstraintSolver.Variable)
Base.:(==)(x::ConstraintSolver.LinearVariables, y::ConstraintSolver.LinearVariables)
ConstraintSolver.equal(variables::Vector{ConstraintSolver.Variable})
Base.:(==)(x::ConstraintSolver.Variable, y::ConstraintSolver.Variable)
Base.:!(bc::ConstraintSolver.BasicConstraint)
```

### Objective functions

```@docs
ConstraintSolver.vars_max(vars::Vector{ConstraintSolver.Variable})
```
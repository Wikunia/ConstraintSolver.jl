# ConstrainSolver.jl - Changelog

## Unreleased
- **Bugfixes:**
  - EqualSet feasibility: Check if other vars have value + no memory allocation

## v0.1.4 (6th of May 2020)
- Added `is_solved_constraint` functions to check whether problem gets actually solved
- **Bugfixes:**
  - Correct incremental update in table constraint
  - Fixed `restore_pruning_constraint!` in table
  
## v0.1.3 (4th of May 2020)
- **Bugfixes:**
  - Use correct offset in table constraint `support` and `residues`

## v0.1.2 (27th of April 2020)
- Table constraint
  - `@constraint(m, x in CS.TableSet(2dArr))`

## v0.1.1 (15th of April 2020)
- CS.Integers
  - i.e `@variable(m, x, CS.Integers([1,2,5]))`
- **Bugfixes:**
  - return infeasible if start fixing is infeasible [#132](https://github.com/Wikunia/ConstraintSolver.jl/pull/132) 

## 0.1.0 (7th of April 2020)
Initial implementation of the solver:
Basic constraints: 
- AllDifferent
- Linear functions `==`, `>=`, `<=`, `!=`
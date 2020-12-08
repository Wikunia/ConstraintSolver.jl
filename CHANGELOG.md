# ConstrainSolver.jl - Changelog

## v0.5.0 (8th of December 2020)
- Using a priority queue for faster `get_next_node`
- Removed `further_pruning`

## v0.4.1 (8th of December 2020)
- Using faster version of strongly connected components with lower memory footprint
- Bugfix in reified constraint:
  - If inner constraint can't be activated it shouldn't be solved
    - Bug found by @hakank see [Issue #202](https://github.com/Wikunia/ConstraintSolver.jl/issues/202)

## v0.4.0 (29th of November 2020)
**Improvements for graph coloring**
- Use LP solver also for single variable objectives
- Combine several `x != y` constraints into an all different constraint
- Combine several `a >= x` constraints with the same `a` into a vector constraints
  - used for better bounds using all different constraints

## v0.3.1 (16th of November 2020)
- Added `copy` function for constraint structs for latest JuMP/MOI versions

## v0.3.0 (11th of July 2020)
- Reified constraint [#171](https://github.com/Wikunia/ConstraintSolver.jl/pull/171)

## v0.2.2 (26th of June 2020)
- Actually use best bound [#175](https://github.com/Wikunia/ConstraintSolver.jl/pull/175)
- Select next var based on objective (still hacky solution) [#176](https://github.com/Wikunia/ConstraintSolver.jl/issues/176)

## v0.2.1 (26th of June 2020)
- Bugfixes in indicator constraint [#170](https://github.com/Wikunia/ConstraintSolver.jl/issues/170)
  - Calling finished constraints and other functions for i.e `TableConstraint` as an inner constraint
  - Use correct best bound when inactive vs active

## v0.2.0 (17th of June 2020)
- Bugfix for indicator constraints
    - support for TableConstraint in Indicator

## v0.1.8 (15th of June 2020)
- Support for indicator constraints
    - i.e. `@constraint(m, b => { x + y <= 10 })`

## v0.1.7 (22th of May 2020)
- Better feasibility and pruning in `==`
- **Bugfixes:**
  - Correct set of change ptr in `EqualSet` for faster/correct pruning
  - Call to `isapprox_discrete` in `eq_sum`
  - Fixed threshold rounding

## v0.1.6 (11th of May 2020)
- Reduction of memory allocations in `TableConstraint`
- Pruning in `EqualSet`

## v0.1.5 (6th of May 2020)
- **Bugfixes:**
  - EqualSet feasibility: Check if other vars have value + no memory allocation
  - Call `call_finished_pruning!(com)` after second `prune!` before backtracking

## v0.1.4 (6th of May 2020)
- Added `is_constraint_solved` functions to check whether problem gets actually solved
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
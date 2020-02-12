[![Build Status](https://travis-ci.org/Wikunia/ConstraintSolver.jl.svg?branch=master)](https://travis-ci.org/Wikunia/ConstraintSolver.jl) [![codecov](https://codecov.io/gh/Wikunia/ConstraintSolver.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Wikunia/ConstraintSolver.jl)
[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://wikunia.github.io/ConstraintSolver.jl/dev)

# ConstraintSolver.jl

This package aims to be a constraint solver written in Julia and will be documented completely on my blog [OpenSourc.es](https://opensourc.es/blog/constraint-solver-1)

In general it's the goal to be as fast as possible but also as a teaching project on how one can do such a project by himself.
I'm just a MSc student in computer science so I don't have much knowledge on how constraint programming works but I'm keen to find out ;)

## Blog posts
- [Setup of the solver and basic backtracking for Sudoku](https://opensourc.es/blog/constraint-solver-1)
- [Pruning in Sudoku](https://opensourc.es/blog/constraint-solver-pruning)
- [More pruning and benchmarks](https://opensourc.es/blog/constraint-solver-pruning-benchmarking)
- [Sophisticated implementation of the alldifferent constraint and benchmarks](https://opensourc.es/blog/constraint-solver-alldifferent)
- [New data structure for better user interface and performance](https://opensourc.es/blog/constraint-solver-data-structure)
- [Backtrack without recursion and start of sum constraint](https://opensourc.es/blog/constraint-solver-backtrack-sum)
- [Speed up the sum constraint](https://opensourc.es/blog/constraint-solver-sum-speed)
- [UI changes and refactoring](https://opensourc.es/blog/constraint-solver-ui-refactor)
- [Recap video](https://opensourc.es/blog/constraint-solver-first-recap)
- [First step in graph coloring](https://opensourc.es/blog/constraint-solver-simple-graph-coloring)
- [Comarison with MIP using graph coloring](https://opensourc.es/blog/constraint-solver-mip-graph-coloring)
- [Documentation with Documenter.jl and newest Benchmarking results](https://opensourc.es/blog/constraint-solver-docs-and-benchmarks)
- [How to profile Julia code](https://opensourc.es/blog/constraint-solver-profiling)
- [Second take on bipartite matchings](https://opensourc.es/blog/constraint-solver-bipartite-matching)
- [Making it a JuMP solver](https://opensourc.es/blog/constraint-solver-jump)
- [Dealing with real objectives](https://opensourc.es/blog/constraint-solver-floats)
- [Support for linear objectives](https://opensourc.es/blog/constraint-solver-linear-objective)

## Installation
You can install this julia package using 
`] add https://github.com/Wikunia/ConstraintSolver.jl` or if you want to change code you might want to use
`] dev https://github.com/Wikunia/ConstraintSolver.jl`.

If everything goes well I will make a request to make this a julia package but that needs some more blog posts to make it a real constraint solver and not just something to play around with and solve sudokus.

## Support
If you find a bug or improvement please open an issue or make a pull request. 
You just enjoy reading and want to see more posts and get them earlier? Support me on [Patreon](https://www.patreon.com/opensources)

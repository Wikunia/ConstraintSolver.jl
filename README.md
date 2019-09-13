# ConstraintSolver.jl

This package aims to be a constraint solver written in Julia and will be documented completely on my blog [OpenSourc.es](https://opensourc.es/blog/constraint-solver-1)

In general it's the goal to be as fast as possible but also as a teaching project on how one can do such a project by himself.
I'm just a MSc student in computer science so I don't have much knowledge on how constraint programming works but I'm keen to find out ;)

## Blog
- [Setup of the solver and basic backtracking for Sudoku](https://opensourc.es/blog/constraint-solver-1)
- [Pruning in Sudoku](https://opensourc.es/blog/constraint-solver-pruning)
- [More pruning and benchmarks](https://opensourc.es/blog/constraint-solver-pruning-benchmarking)
- [Sophisticated implementation of the alldifferent constraint and benchmarks](https://opensourc.es/blog/constraint-solver-alldifferent)

## Installation
You can install this julia package using 
`] add https://github.com/Wikunia/ConstraintSolver.jl` or if you want to change code you might want to use
`] dev https://github.com/Wikunia/ConstraintSolver.jl`.

If everything goes well I will make a request to make this a julia package but that needs some more blog posts to make it a real constraint solver and not just something to play around with and solve sudokus.

## Support
If you find a bug or improvement please open an issue or make a pull request. 
You just enjoy reading and want to see more posts? Support me on [Patreon](https://www.patreon.com/opensources)

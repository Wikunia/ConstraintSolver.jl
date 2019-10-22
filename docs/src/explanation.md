# Explanation

In this part I'll explain how the constraint solver works. You might want to read this either because you're just interested or because you might want to contribute to this project.

This project evolved during a couple of months and is more or less fully documented on my blog: [Constraint Solver Series](https://opensourc.es/blog/constraint-solver-1).

That is an ongoing project and there were a lot of changes especially at the beginning. Therefore here you can read just the current state in a shorter format.

## General concept

The constraint solver works on a set of discrete bounded variables. In the solving process the first step is to go through all constraints and remove values which aren't possible i.e if we have a `all_different([x,y])` constraint and `x` is fixed to 3 it can be removed from the possible set of values for `y` directly.

Now that `y` changed this might lead to further improvements by calling constraints where `y` is involved. By improvement I mean that the search space gets smaller.

After this step it might turn out that the problem is infeasible or solved but most of the time it's not yet known. That is when backtracking comes in to play.

### Backtracking

In backtracking we split the current model into several models in each of them we fix a variable to one particular value. This creates a tree structure.
The constraint solver decides how to split the model into several parts. Most often it is useful to split it into a few parts rather than many parts. That means if we have two variables `x` and `y` and `x` has 3 possible values after the first step and `y` has 9 possible values we rather choose `x` to create three new branches in our tree than 9. This is useful as we get more information per solving step this way. 

After we fix a value we go into one of the open nodes. An open node is a node in the tree which we didn't split yet (it's a leaf node) and is neither infeasible nor is a fixed solution. 

There are two kind of problems which have a different backtracking strategy. One of them is a feasibility problem like solving sudokus and the other one is an optimization problem like graph coloring.

In the first way we try one branch until we reach a leaf node and then backtrack until we prove that the problem is infeasible or stop when we found a feasible solution.

For optimization problems a node is chosen which has the best bound (best possible objective) and if there are several ones the one with the highest depth is chosen.

In general the solver saves what changed in each step to be able to update the current search space when jumping to a different open node in the tree.




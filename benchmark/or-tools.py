import sys
import time
import numpy as np

from ortools.sat.python import cp_model

def from_file(filename, sep='\n'):
  "Parse a file into a list of strings, separated by sep."
  lines = open(filename).read().strip().split(sep)
  grids = []
  for line in lines:
    line = line.replace(".","0")
    grid = list(line)
    grid = list(map(int, grid))
    grid = np.reshape(grid, (9,9))
    grids.append(grid.tolist())
  return grids

def solve(pidx, problem):
  n = 9

  # Create model
  model = cp_model.CpModel()

  # variables
  x = {}
  for i in range(n):
    for j in range(n):
      x[i, j] = model.NewIntVar(1, n, "x[%i,%i]" % (i, j))

  x_flat = [x[i, j] for i in range(n) for j in range(n)]

  # all rows and columns must be unique
  for i in range(n):
    row = [x[i, j] for j in range(n)]
    model.AddAllDifferent(row)

    col = [x[j, i] for j in range(n)]
    model.AddAllDifferent(col)

  # cells
  for i in range(2):
    for j in range(2):
      cell = [x[r, c]
              for r in range(i * 3, i * 3 + 3)
              for c in range(j * 3, j * 3 + 3)]
      model.AddAllDifferent(cell)

  for i in range(n):
    for j in range(n):
      if problem[i][j]:
        model.Add(x[i, j] == problem[i][j])

  # search and solution
  solver = cp_model.CpSolver()
  solver.parameters.log_search_progress = True
  status = solver.Solve(model)
  print(str(pidx)+",",solver.WallTime())

if __name__ == "__main__":
  grids = from_file("top95.txt")
  i = 0
  for grid in grids:
	  solve(i, grid)
	  i += 1
import sys
import time
import numpy as np
import json

from ortools.sat.python import cp_model

def parse_problem(filename):
  json_txt = open("data/"+filename).read()
  problem = json.loads(json_txt)
  return problem

def solve(pidx, filename):
  problem = parse_problem(filename)

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

  for s in problem:
    model.Add(sum(x[i[0]-1,i[1]-1] for i in s["indices"]) == s["result"])
    model.AddAllDifferent([x[i[0]-1,i[1]-1] for i in s["indices"]])

  

  # search and solution
  solver = cp_model.CpSolver()
  status = solver.Solve(model)
  print(str(pidx)+",",solver.WallTime())

if __name__ == "__main__":
  i = 0
  for filename in ["niallsudoku_5500", "niallsudoku_5501", "niallsudoku_5502", "niallsudoku_5503", "niallsudoku_6417",
                  "niallsudoku_6249"]:
	  solve(i, filename)
	  i += 1
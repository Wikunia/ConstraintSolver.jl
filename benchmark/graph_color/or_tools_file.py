import sys
import time
import numpy as np
import json

from ortools.sat.python import cp_model

def solve(pidx, filename):
  # Open the file with read only permit
  f = open(filename, "r")
  # use readlines to read all lines in the file
  # The variable "lines" is a list containing all lines in the file
  lines = f.readlines()
  # close the file after reading the lines.
  f.close()


  # Create model
  model = cp_model.CpModel()

  x =[]
  num_colors = 0
  for line in lines:
    parts = line.strip().split(" ")
    if parts[0] == 'p':
      num_colors = int(parts[2])
      for i in range(num_colors):
        x.append(model.NewIntVar(1, num_colors, str(i)))
    elif parts[0] == 'e':
      f = int(parts[1])-1
      t = int(parts[2])-1
      model.Add(x[f] != x[t])
 
  max_color = model.NewIntVar(1, num_colors, "max_color")

  model.AddMaxEquality(max_color, x)

  model.Minimize(max_color)

  # search and solution
  solver = cp_model.CpSolver()
  status = solver.Solve(model)
  print(str(pidx)+",",solver.WallTime())
  print("Status: ", status)
  print("Opt status: ", cp_model.OPTIMAL)
  print('Minimum of objective function: %i' % solver.ObjectiveValue())
  print()
  # for state in x:
    # print(solver.Value(state))

  """
  if status == cp_model.OPTIMAL:
    print('Minimum of objective function: %i' % solver.ObjectiveValue())
    print()
    for state in states:
      print(solver.Value(state))
  """

if __name__ == "__main__":
  i = 0
  solve(i, "data/fpsol2.i.1.col")
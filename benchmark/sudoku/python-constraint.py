# implementation found here: https://gist.github.com/lucaswiman/f6769d2e866407dd784d1f29d3556771

from constraint import *
import time
ROWS = 'abcdefghi'
COLS = '123456789'
DIGITS = range(1, 10)
VARS = [row + col for row in ROWS for col in COLS]
ROWGROUPS = [[row + col for col in COLS] for row in ROWS]
COLGROUPS = [[row + col for row in ROWS] for col in COLS]
SQUAREGROUPS = [
    [ROWS[3 * rowgroup + k] + COLS[3 * colgroup + j]
     for j in range(3) for k in range(3)]
    for colgroup in range(3) for rowgroup in range(3)
]

def solve(prob_num, hints):
    problem = Problem()
    for var, hint in zip(VARS, hints):
        problem.addVariables([var], [hint] if hint in DIGITS else DIGITS)
    for vargroups in [ROWGROUPS, COLGROUPS, SQUAREGROUPS]:
        for vargroup in vargroups:
            problem.addConstraint(AllDifferentConstraint(), vargroup)
    start = time.perf_counter()
    sol = problem.getSolution()
    t = time.perf_counter()-start
    print('%d, %.4f' % (prob_num,t))
    return sol

def pretty(var_to_value):
    board = ''
    for rownum, row in enumerate('abcdefghi'):
        for colnum, col in enumerate('123456789'):
            board += str(var_to_value[row+col])
            if colnum % 3 == 2:
                board += ' '
        board += '\n'
        if rownum % 3 == 2:
            board += '\n'
    return board

def from_file(filename, sep='\n'):
    "Parse a file into a list of strings, separated by sep."
    return open(filename).read().strip().split(sep)

def solve_all(grids):
    for i in range(len(grids)):
        str_grid = grids[i].replace(".", "0")
        grid = list(str_grid)
        grid = tuple([ int(x) for x in grid ])
        solve(i, grid)

if __name__ == '__main__':
    # solve_all(from_file("easy50.txt", '========'), "easy", None)
    solve_all(from_file("top95.txt"))
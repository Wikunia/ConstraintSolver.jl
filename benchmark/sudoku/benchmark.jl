function from_file(filename, sep = '\n')
    s = open(filename) do file
        read(file, String)
    end
    str_sudokus = split(strip(s), sep)
    grids = AbstractArray[]
    for str_sudoku in str_sudokus
        str_sudoku = replace(str_sudoku, "." => "0")
        one_line_grid = parse.(Int, split(str_sudoku, ""))
        grid = reshape(one_line_grid, 9, 9)
        push!(grids, grid)
    end
    return grids
end

function solve_sudoku(grid)
    m = CS.Optimizer(logging = [])

    x = [[MOI.add_constrained_variable(m, MOI.Integer()) for i = 1:9] for j = 1:9]
    for r = 1:9, c = 1:9
        MOI.add_constraint(m, x[r][c][1], MOI.GreaterThan(1.0))
        MOI.add_constraint(m, x[r][c][1], MOI.LessThan(9.0))
    end

    # set variables
    for r = 1:9, c = 1:9
        if grid[r, c] != 0
            sat = [MOI.ScalarAffineTerm(1.0, x[r][c][1])]
            MOI.add_constraint(
                m,
                MOI.ScalarAffineFunction{Float64}(sat, 0.0),
                MOI.EqualTo(convert(Float64, grid[r, c])),
            )
        end
    end
    # sudoku constraints
    for r = 1:9
        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x[r][c][1] for c = 1:9]),
            CS.AllDifferentSetInternal(9),
        )
    end
    for c = 1:9
        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x[r][c][1] for r = 1:9]),
            CS.AllDifferentSetInternal(9),
        )
    end
    variables = [MOI.VariableIndex(0) for _ = 1:9]
    for br = 0:2
        for bc = 0:2
            variables_i = 1
            for i = br*3+1:(br+1)*3, j = bc*3+1:(bc+1)*3
                variables[variables_i] = x[i][j][1]
                variables_i += 1
            end
            MOI.add_constraint(m, variables, CS.AllDifferentSetInternal(9))
        end
    end

    MOI.optimize!(m)
end


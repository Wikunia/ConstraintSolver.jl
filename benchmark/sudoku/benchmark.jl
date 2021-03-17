function from_file(filename, sep = '\n')
    s = open(filename) do file
        read(file, String)
    end
    str_sudokus = split(strip(s), sep)
    grids = AbstractArray[]
    for str_sudoku in str_sudokus
        str_sudoku = replace(str_sudoku, "." => "0")
        one_line_grid = parse.(Int, split(str_sudoku, ""))
        nvals = length(one_line_grid)
        side_len = isqrt(nvals)
        grid = reshape(one_line_grid, side_len, side_len)
        push!(grids, grid)
    end
    return grids
end

function solve_sudoku(grid)
    m = CS.Optimizer(logging = [])
    side_len = size(grid, 1)
    block_size = isqrt(side_len)

    x = [[MOI.add_constrained_variable(m, MOI.Integer()) for i in 1:side_len] for j in 1:side_len]
    for r in 1:side_len, c in 1:side_len
        MOI.add_constraint(m, x[r][c][1], MOI.GreaterThan(1.0))
        MOI.add_constraint(m, x[r][c][1], MOI.LessThan(convert(Float64, side_len)))
    end

    # set variables
    for r in 1:side_len, c in 1:side_len
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
    for r in 1:side_len
        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x[r][c][1] for c in 1:side_len]),
            CS.AllDifferentSetInternal(side_len),
        )
    end
    for c in 1:side_len
        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x[r][c][1] for r in 1:side_len]),
            CS.AllDifferentSetInternal(side_len),
        )
    end
    variables = [MOI.VariableIndex(0) for _ in 1:side_len]
    for br in 0:block_size-1
        for bc in 0:block_size-1
            variables_i = 1
            for i in (br * block_size + 1):((br + 1) * block_size), j in (bc * block_size + 1):((bc + 1) * block_size)
                variables[variables_i] = x[i][j][1]
                variables_i += 1
            end
            MOI.add_constraint(m, variables, CS.AllDifferentSetInternal(side_len))
        end
    end

    MOI.optimize!(m)
    @assert MOI.get(m, MOI.TerminationStatus()) == MOI.OPTIMAL
end

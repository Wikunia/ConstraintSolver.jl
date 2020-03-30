
function sudokus_from_file(filename, sep = '\n')
    s = open(filename) do file
        read(file, String)
    end
    str_sudokus = split(strip(s), sep)
    grids = AbstractArray[]
    for str_sudoku in str_sudokus
        str_sudoku = strip(replace(str_sudoku, "." => "0"))
        if length(str_sudoku) != 81
            continue
        end
        one_line_grid = parse.(Int, split(str_sudoku, ""))
        grid = reshape(one_line_grid, 9, 9)
        push!(grids, grid)
    end
    return grids
end

function create_sudoku_grid!(com, grid)
    com_grid = Array{CS.Variable,2}(undef, 9, 9)
    for (ind, val) in enumerate(grid)
        if val == 0
            com_grid[ind] = CS.add_var!(com, 1, 9)
        else
            com_grid[ind] = CS.add_var!(com, 1, 9; fix = val)
        end
    end
    return com_grid
end

function add_sudoku_constr!(com, grid)
    for rc = 1:9
        #row
        variables = grid[CartesianIndices((rc:rc, 1:9))]
        CS.add_constraint!(com, CS.all_different([variables...]))
        #col
        variables = grid[CartesianIndices((1:9, rc:rc))]
        CS.add_constraint!(com, CS.all_different([variables...]))
    end

    for br = 0:2
        for bc = 0:2
            variables = grid[CartesianIndices((br*3+1:(br+1)*3, bc*3+1:(bc+1)*3))]
            CS.add_constraint!(com, CS.all_different([variables...]))
        end
    end
end

function jump_add_sudoku_constr!(m, x)
    for rc = 1:9
        @constraint(m, x[rc, :] in CS.AllDifferentSet())
        @constraint(m, x[:, rc] in CS.AllDifferentSet())
    end
    for br = 0:2
        for bc = 0:2
            @constraint(
                m,
                vec(x[br*3+1:(br+1)*3, bc*3+1:(bc+1)*3]) in CS.AllDifferentSet()
            )
        end
    end
end

function moi_add_sudoku_constr!(m, x)
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
end

function jump_fulfills_sudoku_constr(vals)
    for r = 1:9
        !allunique(vals[r, :]) && return false
    end
    for c = 1:9
        !allunique(vals[:, c]) && return false
    end
    for br = 0:2
        for bc = 0:2
            !allunique(vec(vals[br*3+1:(br+1)*3, bc*3+1:(bc+1)*3])) && return false
        end
    end
    return true
end

function fulfills_sudoku_constr(com_grid)
    correct = true
    for rc = 1:9
        row = com_grid[CartesianIndices((rc:rc, 1:9))]
        if any(v -> !CS.isfixed(v), row)
            return false
        end
        vals = unique([CS.value(v) for v in row])
        correct = length(vals) != 9 ? false : correct

        col = com_grid[CartesianIndices((1:9, rc:rc))]
        if any(v -> !CS.isfixed(v), col)
            return false
        end
        vals = unique([CS.value(v) for v in col])
        correct = length(vals) != 9 ? false : correct
    end

    for br = 0:2
        for bc = 0:2
            box = com_grid[CartesianIndices((br*3+1:(br+1)*3, bc*3+1:(bc+1)*3))]
            if any(v -> !CS.isfixed(v), box)
                return false
            end
            vals = unique([CS.value(v) for v in box])
            correct = length(vals) != 9 ? false : correct
        end
    end
    return correct
end

function print_search_space(com_grid; max_length = :default)
    if max_length == :default
        if all(v -> CS.isfixed(v), com_grid)
            max_length = 2
        else
            max_length = 20
        end
    end

    for y = 1:size(com_grid)[1]
        line = ""
        for x = 1:size(com_grid)[2]
            if !CS.isfixed(com_grid[y, x])
                possible = sort(values(com_grid[y, x]))
                pstr = join(possible, ",")
                space_left = floor(Int, (max_length - length(pstr)) / 2)
                space_right = ceil(Int, (max_length - length(pstr)) / 2)
                line *= repeat(" ", space_left) * pstr * repeat(" ", space_right)
            else
                pstr = string(CS.value(com_grid[y, x]))
                space_left = floor(Int, (max_length - length(pstr)) / 2)
                space_right = ceil(Int, (max_length - length(pstr)) / 2)
                line *= repeat(" ", space_left) * pstr * repeat(" ", space_right)
            end
        end
        println(line)
    end
end

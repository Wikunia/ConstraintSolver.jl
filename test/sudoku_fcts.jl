function add_sudoku_constr!(com, grid)
    for rc=1:9
        #row
        CS.add_constraint(com, CS.all_different, CartesianIndices((rc:rc,1:9)))
        #col
        CS.add_constraint(com, CS.all_different, CartesianIndices((1:9,rc:rc)))
    end

    for br=0:2
        for bc=0:2
            CS.add_constraint(com, CS.all_different, CartesianIndices((br*3+1:(br+1)*3,bc*3+1:(bc+1)*3)))
        end
    end
end

function fulfills_sudoku_constr(com)
    correct = true
    for rc=1:9
        vals = unique(com.grid[CartesianIndices((rc:rc,1:9))])
        correct = length(vals) != 9 ? false : correct

        vals = unique(com.grid[CartesianIndices((1:9,rc:rc))])
        correct = length(vals) != 9 ? false : correct
    end

    for br=0:2
        for bc=0:2
            vals = unique(com.grid[CartesianIndices((br*3+1:(br+1)*3,bc*3+1:(bc+1)*3))])
            correct = length(vals) != 9 ? false : correct
        end
    end
    return correct
end
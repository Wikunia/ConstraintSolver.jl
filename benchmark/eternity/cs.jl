using ConstraintSolver, JuMP
CS = ConstraintSolver

function read_puzzle(pname)
    dir = pkgdir(ConstraintSolver)
    lines = readlines(pname)
    width, height = parse.(Int, split(lines[1]))
    lines = lines[2:end]
    npieces = length(lines)
    puzzle = zeros(Int, (npieces, 5))
    for i in 1:npieces
        puzzle[i, 1] = i
        parts = split(lines[i], " ")
        puzzle[i, 2:end] = parse.(Int, parts)
    end
    return puzzle, width, height
end

function get_rotations(puzzle)
    npieces = size(puzzle)[1]
    rotations = zeros(Int, (npieces * 4, 5))
    rotation_indices = [[2, 3, 4, 5], [3, 4, 5, 2], [4, 5, 2, 3], [5, 2, 3, 4]]
    for i in 1:npieces
        j = 1
        for rotation in rotation_indices
            rotations[(i - 1) * 4 + j, 1] = i
            rotations[(i - 1) * 4 + j, 2:end] = puzzle[i, rotation]
            j += 1
        end
    end

    return rotations
end

function main(pname; time_limit = 1800)
    puzzle, width, height = read_puzzle(pname)
    rotations = get_rotations(puzzle)
    npieces = size(puzzle)[1]
    ncolors = maximum(puzzle[:, 2:end])

    m = Model(optimizer_with_attributes(CS.Optimizer, "time_limit" => time_limit))

    @variable(m, 1 <= p[1:height, 1:width] <= npieces, Int)
    @variable(m, 0 <= pu[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pr[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pd[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pl[1:height, 1:width] <= ncolors, Int)

    @constraint(m, p[:] in CS.AllDifferent())
    for i in 1:height, j in 1:width
        @constraint(
            m,
            [p[i, j], pu[i, j], pr[i, j], pd[i, j], pl[i, j]] in CS.TableSet(rotations)
        )
    end

    # borders
    # up and down
    for j in 1:width
        @constraint(m, pu[1, j] == 0)
        @constraint(m, pd[height, j] == 0)

        if j != width
            @constraint(m, pr[1, j] == pl[1, j + 1])
            @constraint(m, pr[height, j] == pl[height, j + 1])
        end
    end

    # right and left
    for i in 1:height
        @constraint(m, pl[i, 1] == 0)
        @constraint(m, pr[i, width] == 0)

        if i != height
            @constraint(m, pd[i, 1] == pu[i + 1, 1])
            @constraint(m, pd[i, width] == pu[i + 1, width])
        end
    end

    for i in 1:(height - 1), j in 1:(width - 1)
        @constraint(m, pd[i, j] == pu[i + 1, j])
        @constraint(m, pr[i, j] == pl[i, j + 1])
    end


    if width == height
        start_piece = findfirst(i -> count(c -> c == 0, puzzle[i, :]) == 2, 1:npieces)
        @constraint(m, p[1, 1] == start_piece)
    end

    optimize!(m)

    status = JuMP.termination_status(m)
    if status == MOI.OPTIMAL
        print("$status, $(JuMP.objective_value(m)), $(JuMP.solve_time(m))")
    else
        print("$status, NaN, $(time_limit)")
    end
end

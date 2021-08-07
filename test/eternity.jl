function read_puzzle(fname)
    lines = readlines("data/$fname")
    npieces = length(lines)
    puzzle = zeros(Int, (npieces, 5))
    for i in 1:npieces
        puzzle[i, 1] = i
        parts = split(lines[i], " ")
        puzzle[i, 2:end] = parse.(Int, parts)
    end
    return puzzle
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

@testset "Eternity 6x5" begin
    width = 6
    height = 5
    puzzle = read_puzzle("eternity_6x5")
    rotations = get_rotations(puzzle)
    npieces = size(puzzle)[1]

    ncolors = maximum(puzzle[:, 2:end])

    m = Model(optimizer_with_attributes(CS.Optimizer, "keep_logs" => true, "logging" => []))
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
    com = CS.get_inner_model(m)
    @test is_solved(com)

    status = JuMP.termination_status(m)
    @test status == MOI.OPTIMAL

    @test general_tree_test(com)
end

@testset "Eternity 5x5 Indicator" begin
    width = 5
    height = 5
    puzzle = read_puzzle("eternity_5x5")
    rotations = get_rotations(puzzle)
    npieces = size(puzzle)[1]

    ncolors = maximum(puzzle[:, 2:end])

    m = Model(optimizer_with_attributes(CS.Optimizer, "keep_logs" => true, "logging" => []))
    @variable(m, 1 <= p[1:height, 1:width] <= npieces, Int)
    @variable(m, 0 <= pu[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pr[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pd[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pl[1:height, 1:width] <= ncolors, Int)
    @variable(m, indicator, Bin)

    @constraint(m, p[:] in CS.AllDifferent())
    for i in 1:height, j in 1:width
        @constraint(
            m,
            indicator => {
                [p[i, j], pu[i, j], pr[i, j], pd[i, j], pl[i, j]] in CS.TableSet(rotations),
            }
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

    @objective(m, Max, indicator)

    optimize!(m)
    com = CS.get_inner_model(m)
    # check that indicator is set to 1
    @test JuMP.objective_value(m) ≈ 1.0
    @test is_solved(com)

    status = JuMP.termination_status(m)
    @test status == MOI.OPTIMAL

    @test general_tree_test(com)
end

@testset "Eternity 5x5 Reified" begin
    width = 5
    height = 5
    puzzle = read_puzzle("eternity_5x5")
    rotations = get_rotations(puzzle)
    npieces = size(puzzle)[1]

    ncolors = maximum(puzzle[:, 2:end])

    m = Model(optimizer_with_attributes(CS.Optimizer, "keep_logs" => true, "logging" => []))
    @variable(m, 1 <= p[1:height, 1:width] <= npieces, Int)
    @variable(m, 0 <= pu[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pr[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pd[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pl[1:height, 1:width] <= ncolors, Int)
    @variable(m, reified[1:height, 1:width], Bin)

    @constraint(m, p[:] in CS.AllDifferent())
    for i in 1:height, j in 1:width
        @constraint(
            m,
            reified[i, j] := {
                [p[i, j], pu[i, j], pr[i, j], pd[i, j], pl[i, j]] in CS.TableSet(rotations),
            }
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

    @objective(m, Max, sum(reified))

    optimize!(m)
    com = CS.get_inner_model(m)
    # check that all reified variables are set to 1
    @test JuMP.objective_value(m) ≈ width * height
    @test is_solved(com)

    status = JuMP.termination_status(m)
    @test status == MOI.OPTIMAL

    @test general_tree_test(com)
end

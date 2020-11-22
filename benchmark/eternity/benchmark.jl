function read_puzzle(fname)
    dir = pkgdir(ConstraintSolver)
    lines = readlines(joinpath(dir, "benchmark/eternity/data/$fname"))
    npieces = length(lines)
    puzzle = zeros(Int, (npieces, 5))
    for i=1:npieces
        puzzle[i,1] = i
        parts = split(lines[i], " ")
        puzzle[i,2:end] = parse.(Int, parts)
    end
    return puzzle
end

function get_rotations(puzzle)
    npieces = size(puzzle)[1]
    rotations = zeros(Int, (npieces*4,5))
    rotation_indices = [[2,3,4,5], [3,4,5,2], [4,5,2,3], [5,2,3,4]]
    for i=1:npieces
        j = 1
        for rotation in rotation_indices
            rotations[(i-1)*4+j, 1] = i
            rotations[(i-1)*4+j, 2:end] = puzzle[i,rotation]
            j += 1
        end
    end

    return rotations
end

function solve_eternity(fname="eternity_7"; height=nothing, width=nothing, all_solutions=false, optimize=false, indicator=false, reified=false, branch_strategy=:Auto)
    puzzle = read_puzzle(fname)
    rotations = get_rotations(puzzle)
    npieces = size(puzzle)[1]
    width === nothing && (width = convert(Int, sqrt(npieces)))
    height === nothing && (height = convert(Int, sqrt(npieces)))
    ncolors = maximum(puzzle[:,2:end])

    m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [:Info, :Table],
                "all_solutions"=>all_solutions, "seed"=>1, "branch_strategy"=>branch_strategy))
    if optimize
        cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        m = Model(optimizer_with_attributes(CS.Optimizer, "logging" => [], "all_solutions"=>all_solutions, "lp_optimizer" => cbc_optimizer))
    end

    @variable(m, 1 <= p[1:height, 1:width] <= npieces, Int)
    @variable(m, 0 <= pu[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pr[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pd[1:height, 1:width] <= ncolors, Int)
    @variable(m, 0 <= pl[1:height, 1:width] <= ncolors, Int)
    if indicator
        @variable(m, b, Bin)
    elseif reified
        @variable(m, b[1:height, 1:width], Bin)
    end

    @constraint(m, p[:] in CS.AllDifferentSet())
    for i=1:height, j=1:width
        if indicator
            @constraint(m, b => {[p[i,j], pu[i,j], pr[i,j], pd[i,j], pl[i,j]] in CS.TableSet(rotations)})
        elseif reified
            @constraint(m, b[i,j] := {[p[i,j], pu[i,j], pr[i,j], pd[i,j], pl[i,j]] in CS.TableSet(rotations)})
        else
            @constraint(m, [p[i,j], pu[i,j], pr[i,j], pd[i,j], pl[i,j]] in CS.TableSet(rotations))
        end
    end

    # borders
    # up and down
    for j=1:width
        @constraint(m, pu[1,j] == 0)
        @constraint(m, pd[height,j] == 0)

        if j != width
            @constraint(m, pr[1,j] == pl[1,j+1])
            @constraint(m, pr[height,j] == pl[height,j+1])
        end
    end

     # right and left
     for i=1:height
        @constraint(m, pl[i,1] == 0)
        @constraint(m, pr[i,width] == 0)

        if i != height
            @constraint(m, pd[i,1] == pu[i+1,1])
            @constraint(m, pd[i,width] == pu[i+1,width])
        end
    end

    for i=1:height-1, j=1:width-1
        @constraint(m, pd[i,j] == pu[i+1, j])
        @constraint(m, pr[i,j] == pl[i, j+1])
    end

    if !optimize && indicator
        @constraint(m, b == 1)
    end

    if !optimize && width == height
        start_piece = findfirst(i->count(c->c == 0, puzzle[i,:]) == 2,1:npieces)
        @constraint(m, p[1,1] == start_piece)
    elseif optimize
        if indicator
            @objective(m, Max, 1000*b + p[1,1] + p[1,2])
        elseif reified
            @objective(m, Max, sum(b))
        else
            @objective(m, Max, p[1,1] + p[1,2])
        end
    end

    optimize!(m)

    status = JuMP.termination_status(m)
    @assert status == MOI.OPTIMAL
end

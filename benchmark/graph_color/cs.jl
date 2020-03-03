using ConstraintSolver
CS = ConstraintSolver

function main(filename; benchmark = false)
    com = CS.ConstraintSolverModel()

    lines = readlines(filename)
    num_colors = 0
    x = nothing
    for line in lines
        parts = split(line, " ")
        if parts[1] == "p"
            num_colors = parse(Int, parts[3])
            x = Vector{CS.Variable}(undef, num_colors)
            for i = 1:num_colors
                x[i] = add_var!(com, 1, num_colors)
            end
        elseif parts[1] == "e"
            f = parse(Int, parts[2])
            t = parse(Int, parts[3])
            add_constraint!(com, x[f] != x[t])
        end
    end
    println("num_colors: ", num_colors)

    set_objective!(com, :Min, CS.vars_max(x))

    status = solve!(com)

    if !benchmark
        println("status: ", status)
        println("objective: ", com.best_sol)
        com.info
    end
end

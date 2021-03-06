using ConstraintSolver, JuMP, GLPK
CS = ConstraintSolver

function main(filename; benchmark = false, time_limit = 100)
    lp_optimizer = optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.GLP_MSG_OFF)
    m = Model(optimizer_with_attributes(
        CS.Optimizer,
        "time_limit" => time_limit,
        "lp_optimizer" => lp_optimizer,
    ))

    lines = readlines(filename)
    num_colors = 0
    x = nothing
    max_color = nothing
    degrees = nothing
    for line in lines
        isempty(line) && continue
        parts = split(line)
        if parts[1] == "p"
            num_colors = parse(Int, parts[3])
            @variable(m, 1 <= max_color <= num_colors, Int)
            @variable(m, 1 <= x[1:num_colors] <= num_colors, Int)
            degrees = zeros(Int, num_colors)
        elseif parts[1] == "e"
            f = parse(Int, parts[2])
            t = parse(Int, parts[3])
            @constraint(m, x[f] != x[t])
            degrees[f] += 1
            degrees[t] += 1
        end
    end
    max_degree = maximum(degrees)

    println("max_degree: ", max_degree)
    println("num_colors: ", num_colors)
    @constraint(m, max_color <= max_degree)

    @constraint(m, max_color .>= x)
    @objective(m, Min, max_color)

    optimize!(m)

    status = JuMP.termination_status(m)
    if status == MOI.OPTIMAL
        print("$status, $(JuMP.objective_value(m)), $(JuMP.solve_time(m))")
    else
        print("$status, NaN, $(time_limit)")
    end
end

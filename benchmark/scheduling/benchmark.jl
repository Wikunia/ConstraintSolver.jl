#=
    The problems are taken from http://www.hakank.org/julia/constraints/

    Thanks a lot to Håkan Kjellerstrand
=#

function cumulative(model, start, duration, resource, limit)
    tasks = [i for i in 1:length(start) if resource[i] > 0 && duration[i] > 0]
    num_tasks = length(tasks)
    times_min_a = round.(Int,[JuMP.lower_bound(start[i]) for i in tasks])
    times_min = minimum(times_min_a)
    times_max_a = round.(Int,[JuMP.upper_bound(start[i])+duration[i] for i in tasks])
    times_max = maximum(times_max_a)
    for t in times_min:times_max
        b  = @variable(model, [1:num_tasks], Bin)
        for i in tasks
            # is this task active during this time t?
            @constraint(model, b[i] := { start[i] <= t && t < start[i]+duration[i]})
        end
        # Check that there's no conflicts in time t
        @constraint(model,sum(b[i]*resource[i] for i in tasks) <= limit)
    end
end

#
# no_overlap(model, begins,durations)
#
# Ensure that there is no overlap between the tasks.
#
function no_overlap(model, begins,durations)
    n = length(begins)
    for i in 1:n, j in i+1:n
        b = @variable(model,[1:2], Bin)
        @constraint(model,b[1] := {begins[i] + durations[i] <= begins[j]})
        @constraint(model,b[2] := {begins[j] + durations[j] <= begins[i]})
        @constraint(model, sum(b) >= 1)
    end
end

# From: http://www.hakank.org/julia/constraints/furniture_moving.jl
function furniture_moving()

    model = Model(optimizer_with_attributes(CS.Optimizer,
                                                            "logging"=>[],

                                                            "traverse_strategy"=>:BFS,
                                                            "branch_split"=>:InHalf, # <-

                                                            # "lp_optimizer" => cbc_optimizer,
                                                            # "lp_optimizer" => glpk_optimizer,
                                                            # "lp_optimizer" => ipopt_optimizer,
                                        ))

    # Furniture moving problem
    n = 4
    # [piano, chair, bed, table]
    durations = [30,10,15,15]
    resources = [3,1,3,2] # people needed per task
    @variable(model, 0 <= start_times[1:n] <= 60, Int)
    @variable(model, 0 <= end_times[1:n]   <= 60, Int)
    @variable(model, 1 <= limit <= 3, Int)
    @variable(model, 0 <= max_time <= 60, Int)
    @constraint(model, end_times .<= max_time)

    for i in 1:n
        @constraint(model,end_times[i] == start_times[i] + durations[i])
    end
    cumulative(model, start_times, durations, resources, limit)

    # @objective(model,Min,max_time)

    optimize!(model)

    status = JuMP.termination_status(model)
    @assert status == MOI.OPTIMAL
    @assert JuMP.value(limit) ≈ 3
end

# from http://www.hakank.org/julia/constraints/organize_day.jl
function organize_day(problem,all_solutions=true)
    # cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
    # glpk_optimizer = optimizer_with_attributes(GLPK.Optimizer)
    # ipopt_optimizer = optimizer_with_attributes(Ipopt.Optimizer)

    model = Model(optimizer_with_attributes(CS.Optimizer,   "all_solutions"=> all_solutions,
                                                            # "all_optimal_solutions"=>all_solutions,
                                                            "logging"=>[],

                                                            "traverse_strategy"=>:BFS,
                                                            # "traverse_strategy"=>:DFS,
                                                            # "traverse_strategy"=>:DBFS,

                                                            # "branch_split"=>:Smallest,
                                                            # "branch_split"=>:Biggest,
                                                            "branch_split"=>:InHalf,

                                                            # https://wikunia.github.io/ConstraintSolver.jl/stable/options/#branch_strategy-(:Auto)
                                                            "branch_strategy" => :IMPS, # default
                                        ))
    tasks = problem[:tasks]
    durations = problem[:durations]
    precedences = problem[:precedences]
    start_time = problem[:start_time]
    end_time = problem[:end_time]


    n = length(tasks)
    @variable(model, start_time <= begins[1:n] <= end_time, Int)
    @variable(model, start_time <= ends[1:n] <= end_time, Int)

    for i in 1:n
        @constraint(model,ends[i] == begins[i] + durations[i])
    end

    no_overlap(model,begins,durations)

    # precedences
    for (a,b) in eachrow(precedences)
        @constraint(model, ends[a] <= begins[b])
    end

    @constraint(model,begins[1] >= 11)

    # Solve the problem
    optimize!(model)

    status = JuMP.termination_status(model)
    # println("status:$status")
    @assert status == MOI.OPTIMAL
    if all_solutions
        @assert MOI.get(model, MOI.ResultCount()) == 5
    end
end

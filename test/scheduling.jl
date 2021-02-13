# Scheduling isn't really possible directly with the solver yet :/
# Most of this file is based on http://www.hakank.org/julia/constraints/
# which is a website by Håkan Kjellerstrand
# please check it out :)

# by  Håkan Kjellerstrand
function cumulative(model, start, duration, resource, limit; times_max = nothing)
    tasks = [i for i in 1:length(start) if resource[i] > 0 && duration[i] > 0]
    num_tasks = length(tasks)

    times_min = minimum(round.(Int,[JuMP.lower_bound(start[i]) for i in tasks]))
    if times_max === nothing
        times_max = maximum(round.(Int,[JuMP.upper_bound(start[i])+duration[i] for i in tasks]))
    end
    for t in times_min:times_max
        b  = @variable(model, [1:num_tasks], Bin)
        for i in tasks
            # The following don't work since ConstraintSolver don't
            # support nonlinear constraints
            # @constraint(model,sum([(start[i] <= t) * (t <= start[i] + duration[i])*resource[i] for i in tasks])  <= b)

            # is this task active during this time t?
            @constraint(model, b[i] := { start[i] <= t && t < start[i]+duration[i] }) # is this task active in time t ?
        end
        # Check that there's no conflicts in time t
        @constraint(model,sum([b[i]*resource[i] for i in tasks]) <= limit)
  end
end

#=
  Furniture moving (scheduling) in Julia ConstraintSolver.jl
  From Marriott & Stuckey: "Programming with constraints", page  112f
  Changed for this test case to be easier ;)

  Model created by Hakan Kjellerstrand, hakank@gmail.com
  See also his Julia page: http://www.hakank.org/julia/
=#
function furniture_moving()
    model = Model(optimizer_with_attributes(CS.Optimizer,
                                                "logging"=>[],
                                                "branch_split"=>:InHalf,
                                                "time_limit"=>50
                                        ))



    # Furniture moving
    n = 4
    # [piano, chair, bed, table]
    durations = [30,10,15,15]
    # resource needed per task
    resources = [1,1,1,1] # <- changed for this test case to solve it faster
    max_end_time = 45
    @variable(model, 0 <= start_times[1:n] <= max_end_time, Int)
    @variable(model, minimum(durations) <= end_times[1:n]  <= max_end_time, Int)
    @variable(model, 1 <= limit <= 3, Int)
    @variable(model, 0 <= max_time <= max_end_time,Int)

    for i in 1:n
        @constraint(model,end_times[i] == start_times[i] + durations[i])
    end
    @constraint(model, end_times .<= max_time)
    cumulative(model, start_times, durations, resources, limit; times_max = max_end_time)

    # Solve the problem
    @objective(model, Min, max_time)
    optimize!(model)

    status = JuMP.termination_status(model)
    @test status == MOI.OPTIMAL
    @test JuMP.value(limit) ≈ 3
    @test JuMP.value(max_time) ≈ 30
    @test JuMP.value(start_times[1]) ≈ 0
    for i = 1:n
        @test JuMP.value(start_times[i])+durations[i] ≈ JuMP.value(end_times[i])
    end
end

@testset "Scheduling" begin
@testset "Furniture" begin
    furniture_moving()
end
end

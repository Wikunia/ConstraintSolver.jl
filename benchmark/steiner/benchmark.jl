function steiner(n)
    model = Model(optimizer_with_attributes(CS.Optimizer,  
        "logging" => [],
        "seed" => 4,

        "traverse_strategy" => :BFS,
        # "traverse_strategy"=>:DFS,
        # "traverse_strategy"=>:DBFS,

        # "branch_split"=>:Smallest,
        # "branch_split"=>:Biggest,
        "branch_split" => :InHalf,

        # https://wikunia.github.io/ConstraintSolver.jl/stable/options/#branch_strategy-(:Auto)
        # "branch_strategy" => :IMPS, # default
        "branch_strategy" => :ABS, # Activity Based Search
        "activity.decay" => 0.999, # default 0.999
        "activity.max_probes" => 1, # default, 10
        "activity.max_confidence_deviation" => 20, # default 20

        # "simplify"=>false,
        # "simplify"=>true, # default

        # "backtrack" => false, # default true
        # "backtrack_sorting" => false, # default true

        # "lp_optimizer" => cbc_optimizer,
        # "lp_optimizer" => glpk_optimizer,
        # "lp_optimizer" => ipopt_optimizer,
    ))

    @assert (n % 6 == 1 || n % 6 == 3)

    nb = round(Int, (n * (n - 1)) / 6) # number of sets

    @variable(model, x[1:nb,1:n], Bin)
    @constraint(model, x[1,1] == 1) # symmetry breaking

    # atmost 1 element in common
    for i in 1:nb
        @constraint(model,sum(x[i,:]) == 3)

        for j in i + 1:nb
            b = @variable(model, [1:n], Bin)
            for k in 1:n 
                @constraint(model, b[k] := { x[i,k] == 1 && x[j,k] == 1 })
            end
            @constraint(model, sum(b) <= 1)
        end
    end


    # Solve the problem
    optimize!(model)

    status = JuMP.termination_status(model)
    @assert status == MOI.OPTIMAL
end
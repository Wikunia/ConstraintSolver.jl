@testset "alldifferent" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:10] <= 5, Int)
    @constraint(m, x in CS.AllDifferentSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.AllDifferentConstraint)[1]

    # doesn't check the length
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1, 2, 3])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [2, 2, 3])

    sorted_min = [1, 1, 2, 2, 3]
    sorted_max = [5, 5, 4, 4, 2]
    @test CS.get_alldifferent_extrema(sorted_min, sorted_max, 3) == (1 + 2 + 3, 5 + 4 + 3)

    sorted_min = [1, 3, 3, 3, 4]
    sorted_max = [9, 7, 7, 7, 5]
    @test CS.get_alldifferent_extrema(sorted_min, sorted_max, 3) == (1 + 3 + 4, 9 + 7 + 6)
    @test CS.get_alldifferent_extrema(sorted_min, sorted_max, 5) ==
          (1 + 3 + 4 + 5 + 6, 9 + 7 + 6 + 5 + 4)

    constr_indices = constraint.indices
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[2],
        5,
    )
    @test CS.fix!(com, com.search_space[constr_indices[2]], 5)
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        5,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    dummy_backtrack_obj.step_nr = 1
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    # now setting it to 5 should be feasible
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        5,
    )

    com.c_backtrack_idx = 1

    # feasible and no changes
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == -5:5
    end
    @test CS.fix!(com, com.search_space[constr_indices[2]], 5)
    @test CS.rm!(com, com.search_space[constr_indices[1]], 1)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[3:end]
        @test sort(CS.values(com.search_space[ind])) == -5:4
    end
    @test sort(CS.values(com.search_space[1])) == [-5, -4, -3, -2, -1, 0, 2, 3, 4]
    @test sort(CS.values(com.search_space[2])) == [5]

    # 3 and 4 are taken by indices 3 and 4 so not available at other positions
    @test CS.remove_below!(com, com.search_space[constr_indices[3]], 3)
    @test CS.remove_below!(com, com.search_space[constr_indices[4]], 3)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[3:4]
        @test sort(CS.values(com.search_space[ind])) == 3:4
    end
    for ind in constr_indices[5:end]
        @test sort(CS.values(com.search_space[ind])) == -5:2
    end
    @test sort(CS.values(com.search_space[1])) == [-5, -4, -3, -2, -1, 0, 2]
    @test sort(CS.values(com.search_space[2])) == [5]

    # we don't need -5
    @test CS.remove_below!(com, com.search_space[constr_indices[1]], -4)
    for ind in constr_indices[5:end]
        @test CS.remove_below!(com, com.search_space[constr_indices[ind]], -4)
    end
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    # but we need -4 to have enough values available
    @test CS.remove_below!(com, com.search_space[constr_indices[1]], -3)
    for ind in constr_indices[5:end]
        @test CS.remove_below!(com, com.search_space[constr_indices[ind]], -3)
    end
    @test !CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
end

@testset "all different with gap in variables" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, x[1:4], CS.Integers([-5, -2, 3, 0, 7]))
    @constraint(m, x in CS.AllDifferentSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.AllDifferentConstraint)[1]
    @test CS.is_constraint_solved(
        constraint,
        constraint.fct,
        constraint.set,
        [-2, 0, 7, -5],
    )
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    constr_indices = constraint.indices
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == [-5, -2, 0, 3, 7]
    end
    @test CS.fix!(com, com.search_space[constr_indices[1]], -5)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[2:4]
        @test sort(CS.values(com.search_space[ind])) == [-2, 0, 3, 7]
    end
    @test CS.rm!(com, com.search_space[constr_indices[2]], -2)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test sort(CS.values(com.search_space[2])) == [0, 3, 7]
    for ind in constr_indices[3:4]
        @test sort(CS.values(com.search_space[ind])) == [-2, 0, 3, 7]
    end

    @test CS.remove_below!(com, com.search_space[constr_indices[3]], 2)
    @test CS.remove_below!(com, com.search_space[constr_indices[4]], 2)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    @test CS.isfixed(com.search_space[2])
    @test CS.value(com.search_space[2]) == 0
    for ind in constr_indices[3:4]
        @test sort(CS.values(com.search_space[ind])) == [3, 7]
    end
end

@testset "all different with huge gap in variables" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, 0 <= x[1:4] <= 3, Int)
    @variable(m, 1000 <= y[1:4] <= 3000, Int)
    @constraint(m, [x...,y...] in CS.AllDifferentSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.AllDifferentConstraint)[1]
    constr_indices = constraint.indices
    @test CS.is_constraint_solved(
        constraint,
        constraint.fct,
        constraint.set,
        [0, 1, 2, 3, 1000, 2000],
    )
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)

    @test CS.fix!(com, com.search_space[constr_indices[5]], 1000)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[6:8]
        @test sort(CS.values(com.search_space[ind])) == 1001:3000
    end
    @test CS.fix!(com, com.search_space[constr_indices[1]], 0)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[2:4]
        @test sort(CS.values(com.search_space[ind])) == 1:3
    end
end

@testset "all different is_constraint_violated test" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:10] <= 5, Int)
    @constraint(m, x in CS.AllDifferentSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.AllDifferentConstraint)[1]

    variables = com.search_space
    @test CS.fix!(com, variables[1], 1; check_feasibility = false)
    @test CS.fix!(com, variables[2], 1; check_feasibility = false)
    @test CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:10] <= 5, Int)
    @constraint(m, x in CS.AllDifferentSet())
    optimize!(m)
    com = CS.get_inner_model(m)

    constraint = get_constraints_by_type(com, CS.AllDifferentConstraint)[1]

    variables = com.search_space
    @test CS.fix!(com, variables[1], 1; check_feasibility = false)
    @test CS.fix!(com, variables[2], 2; check_feasibility = false)
    @test !CS.is_constraint_violated(com, constraint, constraint.fct, constraint.set)
end

@testset "all 8queens solutions" begin 
    n = 8
    model = Model(optimizer_with_attributes(CS.Optimizer, "all_optimal_solutions"=>true, "logging"=>[]))

    @variable(model, 1 <= x[1:n] <= n, Int)
    @constraint(model, x in CS.AllDifferentSet())
    @constraint(model, [x[i] + i for i in 1:n] in CS.AllDifferentSet())
    @constraint(model, [x[i] - i for i in 1:n] in CS.AllDifferentSet())

    optimize!(model)

    status = JuMP.termination_status(model)

    @test status == MOI.OPTIMAL
    num_sols = MOI.get(model, MOI.ResultCount())
    @test num_sols == 92
    for sol in 1:num_sols
        x_val = convert.(Integer,JuMP.value.(x; result=sol))
        @test allunique(x_val)
        @test allunique([x_val[i] + i for i in 1:n])
        @test allunique([x_val[i] - i for i in 1:n])
    end
end
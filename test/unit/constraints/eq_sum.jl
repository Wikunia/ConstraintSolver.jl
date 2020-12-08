@testset "equal_to" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, y[1:3], CS.Integers([-3, 1, 2, 3]))
    @constraint(m, sum(y) + 1 == 5)
    optimize!(m)
    com = JuMP.backend(m).optimizer.model.inner
    constraint = get_constraints_by_type(com, CS.LinearConstraint)[1]

    # doesn't check the length
    # 1+2+1 + constant (1) == 5
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1,2,1])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1,2,2])

    constr_indices = constraint.indices
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        -3,
    )
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[1],
        1,
    )
    # not actually feasible but will not be tested fully here
    CS.fix!(com, com.search_space[constr_indices[1]], 3)
    # will be tested when setting the next
    @test !CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        1,
    )

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1
    # now setting it to 1 should be feasible
    @test CS.still_feasible(
        com,
        constraint,
        constraint.fct,
        constraint.set,
        constr_indices[3],
        1,
    )


    # feasible but remove -3 and 3
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices
        @test sort(CS.values(com.search_space[ind])) == [1, 2]
    end
    @test CS.fix!(com, com.search_space[constr_indices[1]], 2)
    @test CS.prune_constraint!(com, constraint, constraint.fct, constraint.set)
    for ind in constr_indices[2:3]
        @test CS.values(com.search_space[ind]) == [1]
    end
    CS.values(com.search_space[constr_indices[1]]) == [2]
end

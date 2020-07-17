@testset "indicator" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, x, CS.Integers([-3,1,2,3]))
    @variable(m, y, CS.Integers([-3,1,2,3]))
    @variable(m, b, Bin)
    @constraint(m, b => {x+y+1 == 5})
    optimize!(m)
    com = JuMP.backend(m).optimizer.model.inner
    constraint = get_constraints_by_type(com, CS.IndicatorConstraint)[1]

    @test CS.is_solved_constraint(constraint, constraint.std.fct, constraint.std.set, [1,2,2])
    @test !CS.is_solved_constraint(constraint, constraint.std.fct, constraint.std.set, [1,2,3])
    @test CS.is_solved_constraint(constraint, constraint.std.fct, constraint.std.set, [0,2,3])

    constr_indices = constraint.indices
    @test CS.still_feasible(com, constraint, constraint.std.fct, constraint.std.set, -3, constr_indices[2])
    @test CS.still_feasible(com, constraint, constraint.std.fct, constraint.std.set, 1, constr_indices[3])
    # not actually feasible but will not be tested fully here
    CS.fix!(com, com.search_space[constr_indices[1]], 1)
    # will be tested when setting the next
    @test !CS.still_feasible(com, constraint, constraint.std.fct, constraint.std.set, -3, constr_indices[3])

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1
    # now setting it to 1 should be feasible
    @test CS.still_feasible(com, constraint, constraint.std.fct, constraint.std.set, -3, constr_indices[3])

    @test CS.prune_constraint!(com, constraint, constraint.std.fct, constraint.std.set)
    for ind in constr_indices[2:3]
        @test sort(CS.values(com.search_space[ind])) == [-3,1,2,3]
    end
    @test sort(CS.values(com.search_space[1])) == [0,1]
    # feasible but remove -3
    @test CS.fix!(com, com.search_space[constr_indices[1]], 1)
    @test CS.prune_constraint!(com, constraint, constraint.std.fct, constraint.std.set)
    for ind in constr_indices[2:3]
        @test sort(CS.values(com.search_space[ind])) == [1,2,3]
    end
    CS.values(com.search_space[constr_indices[1]]) == [1]
end
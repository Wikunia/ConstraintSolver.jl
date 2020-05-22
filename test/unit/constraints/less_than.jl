@testset "LessThan" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 5, Int)
    @constraint(m, 1.2x+π*y-2z <= 4.71)
    optimize!(m)
    com = JuMP.backend(m).optimizer.model.inner

    constraint = com.constraints[1]
    @test CS.is_solved_constraint(constraint, constraint.std.fct, constraint.std.set, [1,2,3])
    @test !CS.is_solved_constraint(constraint, constraint.std.fct, constraint.std.set, [3,2,1])

    constr_indices = constraint.std.indices
    @test !CS.still_feasible(com, constraint, constraint.std.fct, constraint.std.set, -5, constr_indices[3])
    @test CS.still_feasible(com, constraint, constraint.std.fct, constraint.std.set, -4, constr_indices[3])

    @test CS.fix!(com, com.search_space[constr_indices[2]], 0)
    @test !CS.still_feasible(com, constraint, constraint.std.fct, constraint.std.set, -4, constr_indices[3])

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    com.c_backtrack_idx = 1
 
    # now setting it to -4 should be feasible
    @test CS.still_feasible(com, constraint, constraint.std.fct, constraint.std.set, -4, constr_indices[3])

    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -1 <= x <= 5, Int)
    @variable(m, -1 <= y <= 5, Int)
    @variable(m, -5 <= z <= 5, Int)
    @constraint(m, 1.2x+π*y-2z <= 4.71)
    optimize!(m)
    com = JuMP.backend(m).optimizer.model.inner
    constraint = com.constraints[1]
    constr_indices = constraint.std.indices

    @test CS.prune_constraint!(com, constraint, constraint.std.fct, constraint.std.set)
    @test sort(CS.values(com.search_space[1])) == -1:5
    @test sort(CS.values(com.search_space[2])) == -1:5
    @test sort(CS.values(com.search_space[3])) == -4:5

    @test CS.fix!(com, com.search_space[constr_indices[3]], -4)
    @test CS.prune_constraint!(com, constraint, constraint.std.fct, constraint.std.set)
    @test CS.value(com.search_space[1]) == -1
    @test CS.value(com.search_space[2]) == -1
    @test CS.value(com.search_space[3]) == -4
    @test CS.isfixed(com.search_space[1])
    @test CS.isfixed(com.search_space[2])
    @test CS.isfixed(com.search_space[3])
end
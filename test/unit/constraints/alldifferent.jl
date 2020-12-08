@testset "alldifferent" begin
    m = Model(optimizer_with_attributes(CS.Optimizer, "no_prune" => true, "logging" => []))
    @variable(m, -5 <= x[1:10] <= 5, Int)
    @constraint(m, x in CS.AllDifferentSet())
    optimize!(m)
    com = JuMP.backend(m).optimizer.model.inner

    constraint = get_constraints_by_type(com, CS.AllDifferentConstraint)[1]

    # doesn't check the length
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [1,2,3])
    @test !CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [2,2,3])

    sorted_min = [1,1,2,2,3]
    sorted_max = [5,5,4,4,2]
    @test CS.get_alldifferent_extrema(sorted_min, sorted_max, 3) == (1+2+3, 5+4+3)

    sorted_min = [1,3,3,3,4]
    sorted_max = [9,7,7,7,5]
    @test CS.get_alldifferent_extrema(sorted_min, sorted_max, 3) == (1+3+4, 9+7+6)
    @test CS.get_alldifferent_extrema(sorted_min, sorted_max, 5) == (1+3+4+5+6, 9+7+6+5+4)

    constr_indices = constraint.indices
    @test CS.still_feasible(com, constraint, constraint.fct, constraint.set, constr_indices[2], 5)
    @test CS.fix!(com, com.search_space[constr_indices[2]], 5)
    @test !CS.still_feasible(com, constraint, constraint.fct, constraint.set, constr_indices[3], 5)

    # need to create a backtrack_vec to reverse pruning
    dummy_backtrack_obj = CS.BacktrackObj(com)
    push!(com.backtrack_vec, dummy_backtrack_obj)
    # reverse previous fix
    CS.reverse_pruning!(com, 1)
    # now setting it to 5 should be feasible
    @test CS.still_feasible(com, constraint, constraint.fct, constraint.set, constr_indices[3], 5)

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
    @test sort(CS.values(com.search_space[1])) == [-5,-4,-3,-2,-1,0,2,3,4]
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
    @test sort(CS.values(com.search_space[1])) == [-5,-4,-3,-2,-1,0,2]
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
    com = JuMP.backend(m).optimizer.model.inner

    constraint = get_constraints_by_type(com, CS.AllDifferentConstraint)[1]
    @test CS.is_constraint_solved(constraint, constraint.fct, constraint.set, [-2, 0, 7, -5])
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

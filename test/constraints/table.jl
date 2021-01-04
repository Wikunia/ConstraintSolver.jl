@testset "Table" begin
    @testset "Table Init" begin
        m = CS.Optimizer()
        x = MOI.add_variable(m)
        y = MOI.add_variable(m)
        z = MOI.add_variable(m)
        MOI.add_constraint(m, x, CS.Integers([1, 2]))
        MOI.add_constraint(m, y, CS.Integers([1, 2, 4]))
        MOI.add_constraint(m, z, CS.Integers([1, 2, 3]))

        table = [
            1 1 1
            1 1 2
            1 2 3
            2 1 1
            1 3 2
            1 2 2
            2 1 2
            2 2 1
            2 2 2
        ]

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )

        com = CS.get_inner_model(m)
        constraint = com.constraints[1]

        feasible = CS.init_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible

        # 4 should be removed from y
        @test sort(CS.values(com.search_space[y.value])) == [1, 2]
        # y,4 has no support
        @test CS.get_view(constraint.supports, com, y.value, y.value, 4) == [UInt64(0)]
        # z,2 specific support test
        # 0x4d00000000000000 == 0x0100110100000000000000000000000000000000000000000000000000000000
        @test CS.get_view(constraint.supports, com, z.value, z.value, 2) ==
              [0x4d00000000000000]
        @test constraint.residues[com, y.value, y.value, 4] == 0 # no support
        @test constraint.residues[com, x.value, x.value, 1] == 1

        ############### NOT FEASIBLE IN INIT
        m = CS.Optimizer()
        x = MOI.add_variable(m)
        y = MOI.add_variable(m)
        z = MOI.add_variable(m)
        MOI.add_constraint(m, x, CS.Integers([3, 4]))
        MOI.add_constraint(m, y, CS.Integers([1, 2, 4]))
        MOI.add_constraint(m, z, CS.Integers([1, 2, 3]))

        table = [
            1 1 1
            1 1 2
            1 2 3
            2 1 1
            1 3 2
            1 2 2
            2 1 2
            2 2 1
            2 2 2
        ]

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )

        com = CS.get_inner_model(m)
        constraint = com.constraints[1]

        feasible = CS.init_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test !feasible
    end

    @testset "RSparseBitSet" begin
        bitset = CS.RSparseBitSet()
        bitset.words = [~zero(UInt64), ~zero(UInt64), one(UInt64)]
        bitset.indices = [1, 2, 3]
        bitset.last_ptr = 3
        bitset.mask = [~zero(UInt64), ~zero(UInt64), one(UInt64)]
        CS.clear_mask(bitset)
        @test bitset.mask == [zero(UInt64), zero(UInt64), zero(UInt64)]
        CS.invert_mask(bitset)
        @test bitset.mask == [typemax(UInt64), typemax(UInt64), typemax(UInt64)]

        mask = [UInt64(0), UInt64(7), UInt64(0)]
        @test CS.intersect_index(bitset, mask) == 2

        mask = [UInt64(0), UInt64(0), UInt64(0)]
        @test CS.intersect_index(bitset, mask) == 0

        CS.clear_mask(bitset)
        add = [UInt64(30), UInt64(42), UInt64(0)]
        CS.add_to_mask(bitset, add)
        add = [UInt64(0), UInt64(128), UInt64(7)]
        CS.add_to_mask(bitset, add)
        @test bitset.mask == [UInt64(30), UInt64(128 + 42), UInt64(7)]

        CS.intersect_with_mask(bitset)
        @test bitset.words == [UInt64(30), UInt64(128 + 42), UInt64(1)]
    end

    @testset "Table prune once" begin
        m = CS.Optimizer()
        x = MOI.add_variable(m)
        y = MOI.add_variable(m)
        z = MOI.add_variable(m)
        MOI.add_constraint(m, x, CS.Integers([1, 2]))
        MOI.add_constraint(m, y, CS.Integers([1, 2, 4]))
        MOI.add_constraint(m, z, CS.Integers([1, 2, 3]))

        table = [
            1 1 1
            1 1 2
            1 2 3
            2 1 1
            1 3 2
            1 2 2
            2 1 2
            2 2 1
            2 2 2
        ]

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )

        com = CS.get_inner_model(m)
        constraint = com.constraints[1]

        feasible = CS.init_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible

        CS.rm!(com, com.search_space[x.value], 1)
        feasible = CS.prune_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible
        # the 3 should be removed from z
        @test sort(CS.values(com.search_space[z.value])) == [1, 2]
    end

    @testset "Table prune once, more than 64" begin
        m = CS.Optimizer()
        x = MOI.add_variable(m)
        y = MOI.add_variable(m)
        z = MOI.add_variable(m)
        MOI.add_constraint(m, x, CS.Integers([1, 2, 3, 4, 5, 6, 7, 8, 9]))
        MOI.add_constraint(m, y, CS.Integers([1, 2, 3, 4, 5, 6, 7, 8, 9]))
        MOI.add_constraint(m, z, CS.Integers([1, 2, 3, 4, 5, 6, 7, 8, 9]))

        table = Array{Int64}(undef, (9 * 8 * 7, 3))
        i = 1
        for row in permutations(1:9, 3)
            table[i, :] = row
            i += 1
        end

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )

        com = CS.get_inner_model(m)
        constraint = com.constraints[1]

        feasible = CS.init_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible

        CS.remove_below!(com, com.search_space[x.value], 5)
        # this changes residues
        feasible = CS.prune_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible
        # only 5:9 should be allowed for x but no other changes
        @test sort(CS.values(com.search_space[x.value])) == 5:9
        @test sort(CS.values(com.search_space[y.value])) == 1:9
        @test sort(CS.values(com.search_space[z.value])) == 1:9
        for i in 1:9
            @test constraint.residues[com, y.value, y.value, i] >= 4
            @test constraint.residues[com, z.value, z.value, i] >= 4
        end
    end

    @testset "Table prune once and reverse" begin
        m = CS.Optimizer()
        x = MOI.add_variable(m)
        y = MOI.add_variable(m)
        z = MOI.add_variable(m)
        MOI.add_constraint(m, x, CS.Integers([1, 2]))
        MOI.add_constraint(m, y, CS.Integers([1, 2, 4]))
        MOI.add_constraint(m, z, CS.Integers([1, 2, 3]))

        table = [
            1 1 1
            1 1 2
            1 2 3
            2 1 1
            1 3 2
            1 2 2
            2 1 2
            2 2 1
            2 2 2
        ]

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )

        com = CS.get_inner_model(m)
        constraint = com.constraints[1]

        feasible = CS.init_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible

        words_before_prune = copy(constraint.current.words)

        CS.rm!(com, com.search_space[x.value], 1)
        feasible = CS.prune_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )

        words_after_prune = copy(constraint.current.words)
        @test words_before_prune != words_after_prune

        # x.value 1 must be added again and z.value 3 as well (one removed value)
        CS.single_reverse_pruning!(com.search_space, x.value, 1, 0)
        CS.single_reverse_pruning!(com.search_space, z.value, 1, 0)

        CS.single_reverse_pruning_constraint!(
            com,
            constraint,
            constraint.fct,
            constraint.set,
            com.search_space[x.value],
            1,
        )

        CS.reverse_pruning_constraint!(com, constraint, constraint.fct, constraint.set, 1)

        words_after_rev_prune = copy(constraint.current.words)
        # before init
        @test words_after_rev_prune == fill(~zero(UInt64), 1)

        # the 3 should be possible again
        @test sort(CS.values(com.search_space[z.value])) == [1, 2, 3]
    end

    @testset "2 Tables over same variables prune once" begin
        m = CS.Optimizer()
        x = MOI.add_variable(m)
        y = MOI.add_variable(m)
        z = MOI.add_variable(m)
        MOI.add_constraint(m, x, CS.Integers([1, 2]))
        MOI.add_constraint(m, y, CS.Integers([1, 2, 4]))
        MOI.add_constraint(m, z, CS.Integers([1, 2, 3]))

        table = [
            1 1 1
            1 1 2
            1 2 3
            2 1 1
            1 3 2
            1 2 2
            2 1 2
            2 2 1
            2 2 2
        ]

        table2 = [
            2 1 2
            1 2 2
        ]

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table2),
        )

        com = CS.get_inner_model(m)
        constraint = com.constraints[1]
        constraint2 = com.constraints[2]

        feasible = CS.init_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible

        feasible = CS.init_constraint!(
            com,
            constraint2,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table2),
        )
        @test feasible

        # z = 2 should be fixed
        @test CS.value(com.search_space[z.value]) == 2

        CS.rm!(com, com.search_space[x.value], 1)
        feasible = CS.prune_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible

        feasible = CS.prune_constraint!(
            com,
            constraint2,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table2),
        )
        @test feasible

        @test CS.isfixed(com.search_space[x.value])
        @test CS.isfixed(com.search_space[y.value])
        @test CS.isfixed(com.search_space[z.value])

        @test CS.value(com.search_space[x.value]) == 2
        @test CS.value(com.search_space[y.value]) == 1
        @test CS.value(com.search_space[z.value]) == 2
    end

    @testset "3 Tables over subset variables prune once" begin
        m = CS.Optimizer()
        x = MOI.add_variable(m)
        y = MOI.add_variable(m)
        z = MOI.add_variable(m)
        a = MOI.add_variable(m)
        b = MOI.add_variable(m)
        c = MOI.add_variable(m)
        MOI.add_constraint(m, x, CS.Integers([1, 2]))
        MOI.add_constraint(m, y, CS.Integers([1, 2, 4]))
        MOI.add_constraint(m, z, CS.Integers([1, 2, 3, 4]))
        MOI.add_constraint(m, a, CS.Integers([1, 2, 3]))
        MOI.add_constraint(m, b, CS.Integers([1, 2, 3]))
        MOI.add_constraint(m, c, CS.Integers([1, 2, 3]))

        table = [
            1 1 1
            1 2 2
            1 2 3
            2 1 4
            1 3 2
            1 2 2
            2 1 2
            2 2 1
            2 2 3
        ]

        table2 = [
            2 1 2
            1 2 2
        ]

        table3 = [
            2 1 1
            2 1 2
        ]

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([y, z, a]),
            CS.TableSetInternal(3, table2),
        )

        MOI.add_constraint(
            m,
            MOI.VectorOfVariables([a, b, c]),
            CS.TableSetInternal(3, table3),
        )

        com = CS.get_inner_model(m)
        constraint = com.constraints[1]
        constraint2 = com.constraints[2]
        constraint3 = com.constraints[3]

        feasible = CS.init_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible

        feasible = CS.init_constraint!(
            com,
            constraint2,
            MOI.VectorOfVariables([y, z, a]),
            CS.TableSetInternal(3, table2),
        )
        @test feasible

        feasible = CS.init_constraint!(
            com,
            constraint3,
            MOI.VectorOfVariables([a, b, c]),
            CS.TableSetInternal(3, table3),
        )
        @test feasible

        @test CS.isfixed(com.search_space[a.value])
        @test CS.isfixed(com.search_space[b.value])
        @test CS.value(com.search_space[a.value]) == 2
        @test CS.value(com.search_space[b.value]) == 1

        feasible = CS.prune_constraint!(
            com,
            constraint,
            MOI.VectorOfVariables([x, y, z]),
            CS.TableSetInternal(3, table),
        )
        @test feasible

        feasible = CS.prune_constraint!(
            com,
            constraint2,
            MOI.VectorOfVariables([y, z, a]),
            CS.TableSetInternal(3, table2),
        )
        @test feasible

        feasible = CS.prune_constraint!(
            com,
            constraint3,
            MOI.VectorOfVariables([y, z, a]),
            CS.TableSetInternal(3, table3),
        )
        @test feasible

        @test CS.value(com.search_space[x.value]) == 2
        @test sort(CS.values(com.search_space[z.value])) == [1, 2]
        @test sort(CS.values(com.search_space[c.value])) == [1, 2]
    end
end

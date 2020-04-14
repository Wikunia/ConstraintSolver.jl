@testset "Table Init" begin
    m = CS.Optimizer()
    x = MOI.add_variable(m)
    y = MOI.add_variable(m)
    z = MOI.add_variable(m)
    MOI.add_constraint(m, x, CS.Integers([1,2]))
    MOI.add_constraint(m, y, CS.Integers([1,2,4]))
    MOI.add_constraint(m, z, CS.Integers([1,2,3]))

    table = [
        1 1 1;
        1 1 2;
        1 2 3;
        2 1 1;
        1 3 2;
        1 2 2;
        2 1 2;
        2 2 1;
        2 2 2
    ]

    MOI.add_constraint(
        m,
        MOI.VectorOfVariables([x,y,z]),
        CS.TableSetInternal(3, table),
    )

    com = m.inner
    constraint = com.constraints[1]

    feasible = CS.init_constraint!(
        com,
        constraint,
        MOI.VectorOfVariables([x,y,z]),
        CS.TableSetInternal(3, table)
    )
    @test feasible

    # 4 should be removed from y
    @test sort(CS.values(com.search_space[y.value])) == [1,2]
    # y,4 has no support
    @test constraint.supports[com, y.value, 4] == [UInt64(0)]
    # z,2 specific support test
    # 0x4d00000000000000 == 0x0100110100000000000000000000000000000000000000000000000000000000
    @test constraint.supports[com, z.value, 2] == [0x4d00000000000000]

    ############### NOT FEASIBLE IN INIT
    m = CS.Optimizer()
    x = MOI.add_variable(m)
    y = MOI.add_variable(m)
    z = MOI.add_variable(m)
    MOI.add_constraint(m, x, CS.Integers([3,4]))
    MOI.add_constraint(m, y, CS.Integers([1,2,4]))
    MOI.add_constraint(m, z, CS.Integers([1,2,3]))

    table = [
        1 1 1;
        1 1 2;
        1 2 3;
        2 1 1;
        1 3 2;
        1 2 2;
        2 1 2;
        2 2 1;
        2 2 2
    ]

    MOI.add_constraint(
        m,
        MOI.VectorOfVariables([x,y,z]),
        CS.TableSetInternal(3, table),
    )

    com = m.inner
    constraint = com.constraints[1]

    feasible = CS.init_constraint!(
        com,
        constraint,
        MOI.VectorOfVariables([x,y,z]),
        CS.TableSetInternal(3, table)
    )
    @test !feasible
end
@testset "Table" begin
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
    @test constraint.residues[com, y.value, 4] == 0 # no support 
    @test constraint.residues[com, x.value, 1] == 1

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

@testset "RSparseBitSet" begin
    bitset = CS.RSparseBitSet()
    bitset.words = [~zero(UInt64),~zero(UInt64),one(UInt64)]
    bitset.indices = [1,2,3]
    bitset.last_ptr = 3
    bitset.mask = [~zero(UInt64),~zero(UInt64),one(UInt64)]
    CS.clear_mask(bitset)
    @test bitset.mask == [zero(UInt64),zero(UInt64),zero(UInt64)]
    CS.invert_mask(bitset)
    @test bitset.mask == [typemax(UInt64),typemax(UInt64),typemax(UInt64)]
    
    mask = [UInt64(0),UInt64(7),UInt64(0)]
    @test CS.intersect_index(bitset, mask) == 2

    mask = [UInt64(0),UInt64(0),UInt64(0)]
    @test CS.intersect_index(bitset, mask) == 0

    CS.clear_mask(bitset)
    add = [UInt64(30),UInt64(42),UInt64(0)]
    CS.add_to_mask(bitset, add)
    add = [UInt64(0),UInt64(128),UInt64(7)]
    CS.add_to_mask(bitset, add)
    @test bitset.mask == [UInt64(30),UInt64(128+42),UInt64(7)]

    CS.intersect_with_mask(bitset)
    @test bitset.words == [UInt64(30),UInt64(128+42),UInt64(1)]
end

@testset "Table prune once" begin
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

    CS.rm!(com, com.search_space[x.value], 1; changes=false)
    feasible = CS.prune_constraint!(
        com,
        constraint,
        MOI.VectorOfVariables([x,y,z]),
        CS.TableSetInternal(3, table)
    )
    @test feasible
    # the 3 should be removed
    @test sort(CS.values(com.search_space[z.value])) == [1,2]
end
end
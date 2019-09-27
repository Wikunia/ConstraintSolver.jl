@testset "Small special tests" begin

@testset "Sum" begin
    com = CS.init()

    com_grid = Array{CS.Variable, 1}(undef, 5)
    com_grid[1] = CS.addVar!(com, 1, 9)
    com_grid[2] = CS.addVar!(com, 1, 9; fix=5)
    com_grid[3] = CS.addVar!(com, 1, 9)
    com_grid[4] = CS.addVar!(com, 1, 9)
    com_grid[5] = CS.addVar!(com, 1, 9)
    CS.rm!(com_grid[4], 5)
    CS.remove_above!(com_grid[5], 2)

    # CS.add_constraint!(com, CS.eq_sum, [com_grid[CartesianIndex(ind)] for ind in [1,2]]; rhs=11)
    # CS.add_constraint!(com, CS.eq_sum, [com_grid[CartesianIndex(ind)] for ind in [3,4]]; rhs=11)
    CS.add_constraint!(com, CS.eq_sum, [com_grid[CartesianIndex(ind)] for ind in [2,5]]; rhs=6)
    
    CS.solve!(com; backtrack=false)
    # @test CS.isfixed(com_grid[1])
    # @test CS.value(com_grid[1]) == 6
    @test CS.isfixed(com_grid[5])
    @test CS.value(com_grid[5]) == 1
    # @test !CS.has(com_grid[3], 6)
end
end
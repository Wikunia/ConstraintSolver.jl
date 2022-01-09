@testset "Function tests" begin

    @testset "Logs" begin

        var_states = Dict{Int,Vector{Int}}()
        var_changes = Dict{Int,Vector{Tuple{Symbol,Int,Int,Int}}}()
        activity = Dict{Int,Float64}()
        children = CS.TreeLogNode{Int}[]
        l1 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children,
        )
        l2 = CS.TreeLogNode(
            0,
            :Closed,
            true,
            0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children,
        )
        @test !CS.same_logs(l1, l2)

        # different children order
        children = CS.TreeLogNode{Int}[]
        tln1 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            1,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        tln2 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            2,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        push!(children, tln1)
        push!(children, tln2)
        l1 = CS.TreeLogNode(
            0,
            :Closed,
            false,
            0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children[[1, 2]],
        )
        l2 = CS.TreeLogNode(
            0,
            :Closed,
            false,
            0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children[[2, 1]],
        )
        @test !CS.same_logs(l1, l2)

        # missing one child
        children = CS.TreeLogNode{Float64}[]
        tln1 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0.0,
            1,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Float64}[],
        )
        tln2 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0.0,
            2,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Float64}[],
        )
        push!(children, tln1)
        push!(children, tln2)
        l1 = CS.TreeLogNode(
            0,
            :Closed,
            true,
            0.0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children[[1, 2]],
        )
        l2 = CS.TreeLogNode(
            0,
            :Closed,
            true,
            0.0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children[[1]],
        )
        @test !CS.same_logs(l1, l2)

        # 2 layer children different struture
        children1 = CS.TreeLogNode{Int}[]
        tln13 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            3,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        tln11 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            1,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            [tln13],
        )
        tln12 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            2,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        push!(children1, tln11)
        push!(children1, tln12)
        children2 = CS.TreeLogNode{Int}[]
        tln23 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            3,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        tln21 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            1,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        tln22 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            2,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            [tln23],
        )
        push!(children2, tln21)
        push!(children2, tln22)
        l1 = CS.TreeLogNode(
            0,
            :Closed,
            true,
            0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children1,
        )
        l2 = CS.TreeLogNode(
            0,
            :Closed,
            true,
            0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children2,
        )
        @test !CS.same_logs(l1, l2)

        # 2 layer children different position
        children1 = CS.TreeLogNode{Int}[]
        tln13 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            3,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        tln14 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            4,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        tln11 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            1,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            [tln13, tln14],
        )
        tln12 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            2,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        push!(children1, tln11)
        push!(children1, tln12)
        children2 = CS.TreeLogNode{Int}[]
        tln23 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            3,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        tln24 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            4,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        tln21 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            1,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            [tln24, tln23],
        )
        tln22 = CS.TreeLogNode(
            0,
            :Open,
            true,
            0,
            2,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            CS.TreeLogNode{Int}[],
        )
        push!(children2, tln21)
        push!(children2, tln22)
        l1 = CS.TreeLogNode(
            0,
            :Closed,
            true,
            0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children1,
        )
        l2 = CS.TreeLogNode(
            0,
            :Closed,
            true,
            0,
            0,
            0,
            0,
            0,
            var_states,
            var_changes,
            activity,
            children2,
        )
        @test !CS.same_logs(l1, l2)
    end

    @testset "Traverse" begin
        com = CS.ConstraintSolverModel()
        com.options.traverse_strategy = :DFS
        com.traverse_strategy = Val(:DFS)
        com.sense = MOI.MIN_SENSE
        com.backtrack_vec = Vector{CS.BacktrackObj{Float64}}()
        bounds = [0.4, 0.15, 0.15, 0.1, 0.1]
        depths = [3, 2, 1, 2, 2]
        bo = CS.BacktrackObj(com)
        for i in 1:length(bounds)
            bo.status = :Open
            bo.idx = i
            bo.best_bound = bounds[i]
            bo.depth = depths[i]
            push!(com.backtrack_vec, bo)
            CS.add2priorityqueue(com, com.backtrack_vec[end])
        end
        order = [1, 4, 5, 2, 3]
        for i in 1:length(bounds)
            found, bo = CS.get_next_node(com, com.backtrack_vec, true)
            @test found
            @test bo.idx == order[i]
            CS.close_node!(com, bo.idx)
        end

        com = CS.ConstraintSolverModel()
        com.traverse_strategy = Val(:BFS)
        com.options.traverse_strategy = :BFS
        com.sense = MOI.MIN_SENSE
        com.backtrack_vec = Vector{CS.BacktrackObj{Float64}}()
        bounds = [0.4, 0.15, 0.15, 0.1, 0.1]
        depths = [3, 2, 1, 2, 2]
        bo = CS.BacktrackObj(com)
        for i in 1:length(bounds)
            bo.status = :Open
            bo.idx = i
            bo.best_bound = bounds[i]
            bo.depth = depths[i]
            push!(com.backtrack_vec, bo)
            CS.add2priorityqueue(com, com.backtrack_vec[end])
        end

        order = [4, 5, 2, 3, 1]
        for i in 1:length(bounds)
            found, bo = CS.get_next_node(com, com.backtrack_vec, true)
            @test found
            @test bo.idx == order[i]
            CS.close_node!(com, bo.idx)
        end
    end

    @testset "Demorgan Complement Set" begin
        @test CS.demorgan_complement_set(CS.XorSet) === nothing
        @test CS.demorgan_complement_set(CS.AndSet) == CS.OrSet
        @test CS.demorgan_complement_set(CS.OrSet) == CS.AndSet

        @test CS.demorgan_complement_constraint_type(CS.XorSet) === nothing
        @test CS.demorgan_complement_constraint_type(CS.AndSet) == CS.OrConstraint
        @test CS.demorgan_complement_constraint_type(CS.OrSet) == CS.AndConstraint
    end

    @testset "Complement Set" begin
        @test CS.complement_set(CS.AndSet) === nothing
        @test CS.complement_set(CS.XorSet) == CS.XNorSet
        @test CS.complement_set(CS.XNorSet) == CS.XorSet

        @test CS.complement_constraint_type(CS.AndSet) === nothing
        @test CS.complement_constraint_type(CS.XorSet) == CS.XNorConstraint
        @test CS.complement_constraint_type(CS.XNorSet) == CS.XorConstraint
    end
end

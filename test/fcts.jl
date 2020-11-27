@testset "Function tests" begin

    @testset "Logs" begin

        var_states = Dict{Int,Vector{Int}}()
        var_changes = Dict{Int,Vector{Tuple{Symbol,Int,Int,Int}}}()
        activity = Dict{Int,Float64}()
        children = CS.TreeLogNode{Int}[]
        l1 = CS.TreeLogNode(0, :Open, true, 0, 0, 0, 0, 0, var_states, var_changes, activity, children)
        l2 =
            CS.TreeLogNode(0, :Closed, true, 0, 0, 0, 0, 0, var_states, var_changes, activity, children)
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
        tln11 =
            CS.TreeLogNode(0, :Open, true, 0, 1, 0, 0, 0, var_states, var_changes, activity, [tln13])
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
        tln22 =
            CS.TreeLogNode(0, :Open, true, 0, 2, 0, 0, 0, var_states, var_changes, activity, [tln23])
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

    function create_table_row(table::CS.TableSetup, vec::Vector)
        row = Vector{CS.TableEntry}(undef, length(vec))
        c = 1
        for (col, val) in zip(table.cols, vec)
            row[c] = CS.TableEntry(col.id, convert(col.type, val))
            c += 1
        end
        return row
    end

    @testset "TableLogging" begin
        table = CS.TableSetup(
            [
                CS.TableCol(:open_nodes, "#Open", Int, 10, :center),
                CS.TableCol(:closed_nodes, "#Closed", Int, 10, :center),
                CS.TableCol(:incumbent, "Incumbent", Float64, 20, :center),
                CS.TableCol(:best_bound, "Best Bound", Float64, 20, :center),
                CS.TableCol(:duration, "Time [s]", Float64, 10, :center),
            ],
            Dict(:min_diff_duration => 5.0),
        )
        table_header = CS.get_header(table)
        lines = split(table_header, "\n")
        @test length(lines) == 2
        @test length(lines[2]) == sum([c.width + 2 for c in table.cols])
        @test occursin("#Open", lines[1])
        @test occursin("#Closed", lines[1])

        table_row = create_table_row(table, [0, 0, 1.0, 1.0, 0.203])
        line = CS.get_row(table, table_row)
        @test length(line) == sum([c.width + 2 for c in table.cols])
        line_split = split(line, r"\s+")
        # +2 for first and last empty
        @test length(line_split) == length(table.cols) + 2
        @test line_split[2] == "0"
        # only precision 2
        @test line_split[end-1] == "0.20"

        table_row = create_table_row(table, [1000000000000, 1000000000000, 1.0, 1.0, 0.203])
        line = CS.get_row(table, table_row)
        @test length(line) == sum([c.width + 2 for c in table.cols])
        line_split = split(line, r"\s+")
        # +2 for first and last empty
        @test length(line_split) == length(table.cols) + 2
        @test line_split[2] == ">>"
        @test line_split[3] == ">>"

        # duration too long
        table_row = create_table_row(table, [1, 2, 1.0, 1.0, 10000000000.203])
        line = CS.get_row(table, table_row)
        @test length(line) == sum([c.width + 2 for c in table.cols])
        line_split = split(line, r"\s+")
        # +2 for first and last empty
        @test length(line_split) == length(table.cols) + 2
        @test line_split[end-1] == ">>"

        # better precision for bound
        table_row = create_table_row(table, [1, 2, 1.0, 0.000004, 0.203])
        line = CS.get_row(table, table_row)
        @test length(line) == sum([c.width + 2 for c in table.cols])
        line_split = split(line, r"\s+")
        # +2 for first and last empty
        @test length(line_split) == length(table.cols) + 2
        @test line_split[end-2] == "0.000004"

        @assert CS.push_to_table!(
            table;
            open_nodes = 1,
            closed_nodes = 1,
            incumbent = 1.0,
            best_bound = 1.0,
            duration = 0.1,
        )
        # don't print because the duration difference is less than 5sec
        @assert !CS.push_to_table!(
            table;
            open_nodes = 1,
            closed_nodes = 1,
            incumbent = 1.0,
            best_bound = 1.0,
            duration = 0.2,
        )

        # Incumbent precision too high
        table = CS.TableSetup([
            CS.TableCol(:open_nodes, "#Open", Int, 10, :center),
            CS.TableCol(:closed_nodes, "#Closed", Int, 10, :left),
            CS.TableCol(:incumbent, "Incumbent", Float64, 10, :center), # will get increased to 11
            CS.TableCol(:best_bound, "Best Bound", Float64, 10, :center),
            CS.TableCol(:duration, "Time [s]", Float64, 10, :right),
        ])
        table_row = create_table_row(table, [1, 2, 100000000.02, 0.000004, 0.203])
        line = CS.get_row(table, table_row)
        println("line: $line")
        @test length(line) == sum([c.width + 2 for c in table.cols])
        line_split = split(line, r"\s+")
        # +2 for first and last empty
        @test length(line_split) == length(table.cols) + 2
        @test line_split[4] == "100000000.0"
        @assert CS.push_to_table!(
            table;
            open_nodes = 1,
            closed_nodes = 1,
            incumbent = 1.0,
            best_bound = 1.0,
            duration = 0.1,
        )
        @assert CS.push_to_table!(
            table;
            open_nodes = 1,
            closed_nodes = 1,
            incumbent = 1.0,
            best_bound = 1.0,
            duration = 0.2,
        )

        # need to increase size for #Open
        table = CS.TableSetup([
            CS.TableCol("Open", Int),
            CS.TableCol("#Closed", Int, 10),
            CS.TableCol(:incumbent, "Incumbent", Float64, 20),
            CS.TableCol(:best_bound, "Best Bound", Float64, 20, :center),
            CS.TableCol(:duration, "Time [s]", Float64, 10, :center),
        ])
        table_header = CS.get_header(table)
        lines = split(table_header, "\n")
        @test length(lines) == 2
        @test length(lines[2]) == sum([c.width + 2 for c in table.cols])
        @test length(lines[2]) > sum([1, 10, 20, 20, 10])
        @test occursin("Open", lines[1])
        @test occursin("Closed", lines[1])
    end

    @testset "Traverse" begin
        com = CS.ConstraintSolverModel()
        com.traverse_strategy = Val(:DFS)
        com.sense = MOI.MIN_SENSE
        backtrack_vec = Vector{CS.BacktrackObj{Float64}}()
        bounds = [0.4, 0.15, 0.15, 0.1]
        depths = [3, 2, 1, 2]
        bo = CS.BacktrackObj(com)
        for i = 1:length(bounds)
            bo.status = :Open
            bo.idx = i
            bo.best_bound = bounds[i]
            bo.depth = depths[i]
            push!(backtrack_vec, bo)
        end
        order = [1,4,2,3]
        for i=1:length(bounds)
            found, bo = CS.get_next_node(com, backtrack_vec, true)
            @test found
            @test bo.idx == order[i]
            bo.status = :Closed
        end

        # test Best first search
        com.traverse_strategy = Val(:BFS)
        for i=1:length(bounds)
            backtrack_vec[i].status = :Open
        end
        order = [4,2,3,1]
        for i=1:length(bounds)
            found, bo = CS.get_next_node(com, backtrack_vec, true)
            @test found
            @test bo.idx == order[i]
            bo.status = :Closed
        end
    end
end

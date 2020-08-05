@testset "Graph coloring" begin

    function normal_49_states(; reverse_constraint = false, tests=true, time_limit=Inf)
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "keep_logs" => true,
            "logging" => [],
            "time_limit" => time_limit
        ))
        num_colors = 20

        @variable(m, 1 <= states[1:50] <= num_colors, Int)
        @variable(m, 1 <= max_color <= num_colors, Int)

        washington,
        montana,
        maine,
        north_dakota,
        south_dakota,
        wyoming,
        wisconsin,
        idaho,
        vermont,
        minnesota,
        oregon,
        new_hampshire,
        iowa,
        massachusetts,
        nebraska,
        new_york,
        pennsylvania,
        connecticut,
        rhode_island,
        new_jersey,
        indiana,
        nevada,
        utah,
        california,
        ohio,
        illinois,
        washington_dc,
        delaware,
        west_virginia,
        maryland,
        colorado,
        kentucky,
        kansas,
        virginia,
        missouri,
        arizona,
        oklahoma,
        north_carolina,
        tennessee,
        texas,
        new_mexico,
        alabama,
        mississippi,
        georgia,
        south_carolina,
        arkansas,
        louisiana,
        florida,
        michigan = states

        @constraint(m, washington != oregon)
        @constraint(m, washington != idaho)
        @constraint(m, oregon != idaho)
        @constraint(m, oregon != nevada)
        @constraint(m, oregon != california)
        @constraint(m, california != nevada)
        @constraint(m, california != arizona)
        @constraint(m, nevada != idaho)
        @constraint(m, nevada != utah)
        @constraint(m, nevada != arizona)
        @constraint(m, idaho != montana)
        @constraint(m, idaho != wyoming)
        @constraint(m, idaho != utah)
        @constraint(m, utah != wyoming)
        @constraint(m, utah != colorado)
        @constraint(m, utah != new_mexico)
        @constraint(m, utah != arizona)
        @constraint(m, arizona != colorado)
        @constraint(m, arizona != new_mexico)
        @constraint(m, montana != north_dakota)
        @constraint(m, montana != south_dakota)
        @constraint(m, montana != wyoming)
        @constraint(m, wyoming != south_dakota)
        @constraint(m, wyoming != nebraska)
        @constraint(m, wyoming != colorado)
        @constraint(m, colorado != nebraska)
        @constraint(m, colorado != kansas)
        @constraint(m, colorado != oklahoma)
        @constraint(m, colorado != new_mexico)
        @constraint(m, new_mexico != oklahoma)
        @constraint(m, new_mexico != texas)
        @constraint(m, north_dakota != minnesota)
        @constraint(m, north_dakota != south_dakota)
        @constraint(m, south_dakota != minnesota)
        @constraint(m, south_dakota != iowa)
        @constraint(m, south_dakota != nebraska)
        @constraint(m, nebraska != iowa)
        @constraint(m, nebraska != missouri)
        @constraint(m, nebraska != kansas)
        @constraint(m, kansas != missouri)
        @constraint(m, kansas != oklahoma)
        @constraint(m, oklahoma != arkansas)
        @constraint(m, oklahoma != texas)
        @constraint(m, texas != arkansas)
        @constraint(m, texas != louisiana)
        @constraint(m, minnesota != wisconsin)
        @constraint(m, minnesota != iowa)
        @constraint(m, iowa != wisconsin)
        @constraint(m, iowa != illinois)
        @constraint(m, iowa != missouri)
        @constraint(m, missouri != illinois)
        @constraint(m, missouri != kentucky)
        @constraint(m, missouri != tennessee)
        @constraint(m, missouri != arkansas)
        @constraint(m, arkansas != tennessee)
        @constraint(m, arkansas != mississippi)
        @constraint(m, arkansas != louisiana)
        @constraint(m, louisiana != mississippi)
        @constraint(m, wisconsin != illinois)
        @constraint(m, wisconsin != michigan)
        @constraint(m, illinois != indiana)
        @constraint(m, illinois != kentucky)
        @constraint(m, kentucky != indiana)
        @constraint(m, kentucky != ohio)
        @constraint(m, kentucky != west_virginia)
        @constraint(m, kentucky != virginia)
        @constraint(m, kentucky != tennessee)
        @constraint(m, tennessee != virginia)
        @constraint(m, tennessee != north_carolina)
        @constraint(m, tennessee != georgia)
        @constraint(m, tennessee != alabama)
        @constraint(m, tennessee != mississippi)
        @constraint(m, mississippi != alabama)
        @constraint(m, michigan != indiana)
        @constraint(m, michigan != ohio)
        @constraint(m, indiana != ohio)
        @constraint(m, alabama != georgia)
        @constraint(m, alabama != florida)
        @constraint(m, ohio != pennsylvania)
        @constraint(m, ohio != west_virginia)
        @constraint(m, maine != new_hampshire)
        @constraint(m, new_hampshire != vermont)
        @constraint(m, new_hampshire != massachusetts)
        @constraint(m, vermont != massachusetts)
        @constraint(m, vermont != new_york)
        @constraint(m, massachusetts != new_york)
        @constraint(m, massachusetts != rhode_island)
        @constraint(m, massachusetts != connecticut)
        @constraint(m, connecticut != rhode_island)
        @constraint(m, new_york != connecticut)
        @constraint(m, new_york != pennsylvania)
        @constraint(m, new_york != new_jersey)
        @constraint(m, pennsylvania != new_jersey)
        @constraint(m, pennsylvania != delaware)
        @constraint(m, pennsylvania != maryland)
        @constraint(m, pennsylvania != west_virginia)
        @constraint(m, new_jersey != delaware)
        @constraint(m, maryland != washington_dc)
        @constraint(m, maryland != west_virginia)
        @constraint(m, maryland != virginia)
        @constraint(m, washington_dc != virginia)
        @constraint(m, west_virginia != virginia)
        @constraint(m, virginia != north_carolina)
        @constraint(m, north_carolina != south_carolina)
        @constraint(m, south_carolina != georgia)
        @constraint(m, georgia != florida)

        if reverse_constraint
            @constraint(m, max_color .>= states)
        else
            @constraint(m, states .<= max_color)
        end

        @objective(m, Min, max_color)

        optimize!(m)

        status = JuMP.termination_status(m)

        com = JuMP.backend(m).optimizer.model.inner

        CS.save_logs(com, "graph_color_optimize.json", :states => states, :max_color => max_color)
        rm("graph_color_optimize.json")

        if tests
            @test status == MOI.OPTIMAL
            @test com.best_sol == 4 == JuMP.objective_value(m) == JuMP.objective_bound(m)
            @test maximum([JuMP.value(var) for var in states]) == 4 == JuMP.value(max_color)
            @test 0 <= MOI.get(m, MOI.SolveTime()) < 5
        end
        return com, m
    end

    @testset "49 US states + DC time limit" begin
        com1, m1 = normal_49_states(; time_limit = 0.01, tests=false)
        com2, m2 = normal_49_states()
        info_1 = com1.info
        info_2 = com2.info
        @test info_1.pre_backtrack_calls == info_2.pre_backtrack_calls
        if JuMP.termination_status(m1) == MOI.TIME_LIMIT
            @test info_1.in_backtrack_calls < info_2.in_backtrack_calls
        else
            @test JuMP.termination_status(m1) == MOI.OPTIMAL
        end
        @test 0 <= MOI.get(m1, MOI.SolveTime()) < 0.5
    end


    @testset "49 US states + DC" begin
        com1,_ = normal_49_states(; reverse_constraint = true)
        com2,_ = normal_49_states()
        info_1 = com1.info
        info_2 = com2.info
        @test info_1.pre_backtrack_calls == info_2.pre_backtrack_calls
        @test info_1.backtrack_fixes == info_2.backtrack_fixes
        @test info_1.in_backtrack_calls == info_2.in_backtrack_calls
        @test info_1.backtrack_reverses == info_2.backtrack_reverses
        logs_1 = CS.get_logs(com1)
        logs_2 = CS.get_logs(com2)
        @test CS.sanity_check_log(logs_1[:tree])
        @test CS.same_logs(logs_1[:tree], logs_2[:tree])
    end

    @testset "49 US states + DC without sorting + some states same color" begin
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "keep_logs" => true,
            "backtrack_sorting" => false,
            "logging" => [],
        ))
        num_colors = 8
        @variable(m, 1 <= max_color <= num_colors, Int)

        @variable(m, 1 <= states[1:50] <= num_colors, Int)
        washington,
        montana,
        maine,
        north_dakota,
        south_dakota,
        wyoming,
        wisconsin,
        idaho,
        vermont,
        minnesota,
        oregon,
        new_hampshire,
        iowa,
        massachusetts,
        nebraska,
        new_york,
        pennsylvania,
        connecticut,
        rhode_island,
        new_jersey,
        indiana,
        nevada,
        utah,
        california,
        ohio,
        illinois,
        washington_dc,
        delaware,
        west_virginia,
        maryland,
        colorado,
        kentucky,
        kansas,
        virginia,
        missouri,
        arizona,
        oklahoma,
        north_carolina,
        tennessee,
        texas,
        new_mexico,
        alabama,
        mississippi,
        georgia,
        south_carolina,
        arkansas,
        louisiana,
        florida,
        michigan = states

        @constraint(m, washington != oregon)
        @constraint(m, washington != idaho)
        @constraint(m, oregon != idaho)
        @constraint(m, oregon != nevada)
        @constraint(m, oregon != california)
        @constraint(m, california != nevada)
        @constraint(m, california != arizona)
        @constraint(m, nevada != idaho)
        @constraint(m, nevada != utah)
        @constraint(m, nevada != arizona)
        @constraint(m, idaho != montana)
        @constraint(m, idaho != wyoming)
        @constraint(m, idaho != utah)
        @constraint(m, utah != wyoming)
        @constraint(m, utah != colorado)
        @constraint(m, utah != new_mexico)
        @constraint(m, utah != arizona)
        @constraint(m, arizona != colorado)
        @constraint(m, arizona != new_mexico)
        @constraint(m, montana != north_dakota)
        @constraint(m, montana != south_dakota)
        @constraint(m, montana != wyoming)
        @constraint(m, wyoming != south_dakota)
        @constraint(m, wyoming != nebraska)
        @constraint(m, wyoming != colorado)
        @constraint(m, colorado != nebraska)
        @constraint(m, colorado != kansas)
        @constraint(m, colorado != oklahoma)
        @constraint(m, colorado != new_mexico)
        @constraint(m, new_mexico != oklahoma)
        @constraint(m, new_mexico != texas)
        @constraint(m, north_dakota != minnesota)
        @constraint(m, north_dakota != south_dakota)
        @constraint(m, south_dakota != minnesota)
        @constraint(m, south_dakota != iowa)
        @constraint(m, south_dakota != nebraska)
        @constraint(m, nebraska != iowa)
        @constraint(m, nebraska != missouri)
        @constraint(m, nebraska != kansas)
        @constraint(m, kansas != missouri)
        @constraint(m, kansas != oklahoma)
        @constraint(m, oklahoma != arkansas)
        @constraint(m, oklahoma != texas)
        @constraint(m, texas != arkansas)
        @constraint(m, texas != louisiana)
        @constraint(m, minnesota != wisconsin)
        @constraint(m, minnesota != iowa)
        @constraint(m, iowa != wisconsin)
        @constraint(m, iowa != illinois)
        @constraint(m, iowa != missouri)
        @constraint(m, missouri != illinois)
        @constraint(m, missouri != kentucky)
        @constraint(m, missouri != tennessee)
        @constraint(m, missouri != arkansas)
        @constraint(m, arkansas != tennessee)
        @constraint(m, arkansas != mississippi)
        @constraint(m, arkansas != louisiana)
        @constraint(m, louisiana != mississippi)
        @constraint(m, wisconsin != illinois)
        @constraint(m, wisconsin != michigan)
        @constraint(m, illinois != indiana)
        @constraint(m, illinois != kentucky)
        @constraint(m, kentucky != indiana)
        @constraint(m, kentucky != ohio)
        @constraint(m, kentucky != west_virginia)
        @constraint(m, kentucky != virginia)
        @constraint(m, kentucky != tennessee)
        @constraint(m, tennessee != virginia)
        @constraint(m, tennessee != north_carolina)
        @constraint(m, tennessee != georgia)
        @constraint(m, tennessee != alabama)
        @constraint(m, tennessee != mississippi)
        @constraint(m, mississippi != alabama)
        @constraint(m, michigan != indiana)
        @constraint(m, michigan != ohio)
        @constraint(m, indiana != ohio)
        @constraint(m, alabama != georgia)
        @constraint(m, alabama != florida)
        @constraint(m, ohio != pennsylvania)
        @constraint(m, ohio != west_virginia)
        @constraint(m, maine != new_hampshire)
        @constraint(m, new_hampshire != vermont)
        @constraint(m, new_hampshire != massachusetts)
        @constraint(m, vermont != massachusetts)
        @constraint(m, vermont != new_york)
        @constraint(m, massachusetts != new_york)
        @constraint(m, massachusetts != rhode_island)
        @constraint(m, massachusetts != connecticut)
        @constraint(m, connecticut != rhode_island)
        @constraint(m, new_york != connecticut)
        @constraint(m, new_york != pennsylvania)
        @constraint(m, new_york != new_jersey)
        @constraint(m, pennsylvania != new_jersey)
        @constraint(m, pennsylvania != delaware)
        @constraint(m, pennsylvania != maryland)
        @constraint(m, pennsylvania != west_virginia)
        @constraint(m, new_jersey != delaware)
        @constraint(m, maryland != washington_dc)
        @constraint(m, maryland != west_virginia)
        @constraint(m, maryland != virginia)
        @constraint(m, washington_dc != virginia)
        @constraint(m, west_virginia != virginia)
        @constraint(m, virginia != north_carolina)
        @constraint(m, north_carolina != south_carolina)
        @constraint(m, south_carolina != georgia)
        @constraint(m, georgia != florida)

        # test for EqualSet constraint
        @constraint(m, [california, new_york, florida] in CS.EqualSet())

        @constraint(m, max_color .>= states)

        # test for constant in objective
        @objective(m, Min, max_color + 1.1)

        optimize!(m)

        status = JuMP.termination_status(m)

        com = JuMP.backend(m).optimizer.model.inner
        # -1 for equal Set - length(states) for max_color
        not_equal_constraints = length(com.constraints) - 1 - length(states)
        @test com.info.n_constraint_types.notequal == not_equal_constraints
        @test com.info.n_constraint_types.equality == 1
        @test com.info.n_constraint_types.inequality == length(states)
        @test com.info.n_constraint_types.alldifferent == 0

        CS.save_logs(com, "graph_color_optimize.json")
        rm("graph_color_optimize.json")

        @test status == MOI.OPTIMAL
     
        # all values fixed
        @test com.best_sol ≈ 5.1
        @test maximum([JuMP.value(var) for var in states]) == JuMP.value(max_color) == 4
        @test is_solved(com)
    end

    @testset "49 US states + DC only 3 colors" begin
        m = Model(CSJuMPTestOptimizer())
        num_colors = 3

        @variable(m, 1 <= states[1:50] <= num_colors, Int)
        washington,
        montana,
        maine,
        north_dakota,
        south_dakota,
        wyoming,
        wisconsin,
        idaho,
        vermont,
        minnesota,
        oregon,
        new_hampshire,
        iowa,
        massachusetts,
        nebraska,
        new_york,
        pennsylvania,
        connecticut,
        rhode_island,
        new_jersey,
        indiana,
        nevada,
        utah,
        california,
        ohio,
        illinois,
        washington_dc,
        delaware,
        west_virginia,
        maryland,
        colorado,
        kentucky,
        kansas,
        virginia,
        missouri,
        arizona,
        oklahoma,
        north_carolina,
        tennessee,
        texas,
        new_mexico,
        alabama,
        mississippi,
        georgia,
        south_carolina,
        arkansas,
        louisiana,
        florida,
        michigan = states

        @constraint(m, washington != oregon)
        @constraint(m, washington != idaho)
        @constraint(m, oregon != idaho)
        @constraint(m, oregon != nevada)
        @constraint(m, oregon != california)
        @constraint(m, california != nevada)
        @constraint(m, california != arizona)
        @constraint(m, nevada != idaho)
        @constraint(m, nevada != utah)
        @constraint(m, nevada != arizona)
        @constraint(m, idaho != montana)
        @constraint(m, idaho != wyoming)
        @constraint(m, idaho != utah)
        @constraint(m, utah != wyoming)
        @constraint(m, utah != colorado)
        @constraint(m, utah != new_mexico)
        @constraint(m, utah != arizona)
        @constraint(m, arizona != colorado)
        @constraint(m, arizona != new_mexico)
        @constraint(m, montana != north_dakota)
        @constraint(m, montana != south_dakota)
        @constraint(m, montana != wyoming)
        @constraint(m, wyoming != south_dakota)
        @constraint(m, wyoming != nebraska)
        @constraint(m, wyoming != colorado)
        @constraint(m, colorado != nebraska)
        @constraint(m, colorado != kansas)
        @constraint(m, colorado != oklahoma)
        @constraint(m, colorado != new_mexico)
        @constraint(m, new_mexico != oklahoma)
        @constraint(m, new_mexico != texas)
        @constraint(m, north_dakota != minnesota)
        @constraint(m, north_dakota != south_dakota)
        @constraint(m, south_dakota != minnesota)
        @constraint(m, south_dakota != iowa)
        @constraint(m, south_dakota != nebraska)
        @constraint(m, nebraska != iowa)
        @constraint(m, nebraska != missouri)
        @constraint(m, nebraska != kansas)
        @constraint(m, kansas != missouri)
        @constraint(m, kansas != oklahoma)
        @constraint(m, oklahoma != arkansas)
        @constraint(m, oklahoma != texas)
        @constraint(m, texas != arkansas)
        @constraint(m, texas != louisiana)
        @constraint(m, minnesota != wisconsin)
        @constraint(m, minnesota != iowa)
        @constraint(m, iowa != wisconsin)
        @constraint(m, iowa != illinois)
        @constraint(m, iowa != missouri)
        @constraint(m, missouri != illinois)
        @constraint(m, missouri != kentucky)
        @constraint(m, missouri != tennessee)
        @constraint(m, missouri != arkansas)
        @constraint(m, arkansas != tennessee)
        @constraint(m, arkansas != mississippi)
        @constraint(m, arkansas != louisiana)
        @constraint(m, louisiana != mississippi)
        @constraint(m, wisconsin != illinois)
        @constraint(m, wisconsin != michigan)
        @constraint(m, illinois != indiana)
        @constraint(m, illinois != kentucky)
        @constraint(m, kentucky != indiana)
        @constraint(m, kentucky != ohio)
        @constraint(m, kentucky != west_virginia)
        @constraint(m, kentucky != virginia)
        @constraint(m, kentucky != tennessee)
        @constraint(m, tennessee != virginia)
        @constraint(m, tennessee != north_carolina)
        @constraint(m, tennessee != georgia)
        @constraint(m, tennessee != alabama)
        @constraint(m, tennessee != mississippi)
        @constraint(m, mississippi != alabama)
        @constraint(m, michigan != indiana)
        @constraint(m, michigan != ohio)
        @constraint(m, indiana != ohio)
        @constraint(m, alabama != georgia)
        @constraint(m, alabama != florida)
        @constraint(m, ohio != pennsylvania)
        @constraint(m, ohio != west_virginia)
        @constraint(m, maine != new_hampshire)
        @constraint(m, new_hampshire != vermont)
        @constraint(m, new_hampshire != massachusetts)
        @constraint(m, vermont != massachusetts)
        @constraint(m, vermont != new_york)
        @constraint(m, massachusetts != new_york)
        @constraint(m, massachusetts != rhode_island)
        @constraint(m, massachusetts != connecticut)
        @constraint(m, connecticut != rhode_island)
        @constraint(m, new_york != connecticut)
        @constraint(m, new_york != pennsylvania)
        @constraint(m, new_york != new_jersey)
        @constraint(m, pennsylvania != new_jersey)
        @constraint(m, pennsylvania != delaware)
        @constraint(m, pennsylvania != maryland)
        @constraint(m, pennsylvania != west_virginia)
        @constraint(m, new_jersey != delaware)
        @constraint(m, maryland != washington_dc)
        @constraint(m, maryland != west_virginia)
        @constraint(m, maryland != virginia)
        @constraint(m, washington_dc != virginia)
        @constraint(m, west_virginia != virginia)
        @constraint(m, virginia != north_carolina)
        @constraint(m, north_carolina != south_carolina)
        @constraint(m, south_carolina != georgia)
        @constraint(m, georgia != florida)

        optimize!(m)

        @test JuMP.termination_status(m) == MOI.INFEASIBLE
    end

    @testset "Maximization objective" begin
        m = Model(CSJuMPTestOptimizer())
        num_colors = 20

        @variable(m, 1 <= states[1:50] <= num_colors, Int)
        @variable(m, 1 <= max_color <= num_colors, Int)

        washington,
        montana,
        maine,
        north_dakota,
        south_dakota,
        wyoming,
        wisconsin,
        idaho,
        vermont,
        minnesota,
        oregon,
        new_hampshire,
        iowa,
        massachusetts,
        nebraska,
        new_york,
        pennsylvania,
        connecticut,
        rhode_island,
        new_jersey,
        indiana,
        nevada,
        utah,
        california,
        ohio,
        illinois,
        washington_dc,
        delaware,
        west_virginia,
        maryland,
        colorado,
        kentucky,
        kansas,
        virginia,
        missouri,
        arizona,
        oklahoma,
        north_carolina,
        tennessee,
        texas,
        new_mexico,
        alabama,
        mississippi,
        georgia,
        south_carolina,
        arkansas,
        louisiana,
        florida,
        michigan = states

        @constraint(m, washington != oregon)
        @constraint(m, washington != idaho)
        @constraint(m, oregon != idaho)
        @constraint(m, oregon != nevada)
        @constraint(m, oregon != california)
        @constraint(m, california != nevada)
        @constraint(m, california != arizona)
        @constraint(m, nevada != idaho)
        @constraint(m, nevada != utah)
        @constraint(m, nevada != arizona)
        @constraint(m, idaho != montana)
        @constraint(m, idaho != wyoming)
        @constraint(m, idaho != utah)
        @constraint(m, utah != wyoming)
        @constraint(m, utah != colorado)
        @constraint(m, utah != new_mexico)
        @constraint(m, utah != arizona)
        @constraint(m, arizona != colorado)
        @constraint(m, arizona != new_mexico)
        @constraint(m, montana != north_dakota)
        @constraint(m, montana != south_dakota)
        @constraint(m, montana != wyoming)
        @constraint(m, wyoming != south_dakota)
        @constraint(m, wyoming != nebraska)
        @constraint(m, wyoming != colorado)
        @constraint(m, colorado != nebraska)
        @constraint(m, colorado != kansas)
        @constraint(m, colorado != oklahoma)
        @constraint(m, colorado != new_mexico)
        @constraint(m, new_mexico != oklahoma)
        @constraint(m, new_mexico != texas)
        @constraint(m, north_dakota != minnesota)
        @constraint(m, north_dakota != south_dakota)
        @constraint(m, south_dakota != minnesota)
        @constraint(m, south_dakota != iowa)
        @constraint(m, south_dakota != nebraska)
        @constraint(m, nebraska != iowa)
        @constraint(m, nebraska != missouri)
        @constraint(m, nebraska != kansas)
        @constraint(m, kansas != missouri)
        @constraint(m, kansas != oklahoma)
        @constraint(m, oklahoma != arkansas)
        @constraint(m, oklahoma != texas)
        @constraint(m, texas != arkansas)
        @constraint(m, texas != louisiana)
        @constraint(m, minnesota != wisconsin)
        @constraint(m, minnesota != iowa)
        @constraint(m, iowa != wisconsin)
        @constraint(m, iowa != illinois)
        @constraint(m, iowa != missouri)
        @constraint(m, missouri != illinois)
        @constraint(m, missouri != kentucky)
        @constraint(m, missouri != tennessee)
        @constraint(m, missouri != arkansas)
        @constraint(m, arkansas != tennessee)
        @constraint(m, arkansas != mississippi)
        @constraint(m, arkansas != louisiana)
        @constraint(m, louisiana != mississippi)
        @constraint(m, wisconsin != illinois)
        @constraint(m, wisconsin != michigan)
        @constraint(m, illinois != indiana)
        @constraint(m, illinois != kentucky)
        @constraint(m, kentucky != indiana)
        @constraint(m, kentucky != ohio)
        @constraint(m, kentucky != west_virginia)
        @constraint(m, kentucky != virginia)
        @constraint(m, kentucky != tennessee)
        @constraint(m, tennessee != virginia)
        @constraint(m, tennessee != north_carolina)
        @constraint(m, tennessee != georgia)
        @constraint(m, tennessee != alabama)
        @constraint(m, tennessee != mississippi)
        @constraint(m, mississippi != alabama)
        @constraint(m, michigan != indiana)
        @constraint(m, michigan != ohio)
        @constraint(m, indiana != ohio)
        @constraint(m, alabama != georgia)
        @constraint(m, alabama != florida)
        @constraint(m, ohio != pennsylvania)
        @constraint(m, ohio != west_virginia)
        @constraint(m, maine != new_hampshire)
        @constraint(m, new_hampshire != vermont)
        @constraint(m, new_hampshire != massachusetts)
        @constraint(m, vermont != massachusetts)
        @constraint(m, vermont != new_york)
        @constraint(m, massachusetts != new_york)
        @constraint(m, massachusetts != rhode_island)
        @constraint(m, massachusetts != connecticut)
        @constraint(m, connecticut != rhode_island)
        @constraint(m, new_york != connecticut)
        @constraint(m, new_york != pennsylvania)
        @constraint(m, new_york != new_jersey)
        @constraint(m, pennsylvania != new_jersey)
        @constraint(m, pennsylvania != delaware)
        @constraint(m, pennsylvania != maryland)
        @constraint(m, pennsylvania != west_virginia)
        @constraint(m, new_jersey != delaware)
        @constraint(m, maryland != washington_dc)
        @constraint(m, maryland != west_virginia)
        @constraint(m, maryland != virginia)
        @constraint(m, washington_dc != virginia)
        @constraint(m, west_virginia != virginia)
        @constraint(m, virginia != north_carolina)
        @constraint(m, north_carolina != south_carolina)
        @constraint(m, south_carolina != georgia)
        @constraint(m, georgia != florida)

        @constraint(m, max_color .<= states)

        @objective(m, Max, max_color)

        optimize!(m)

        status = JuMP.termination_status(m)

        com = JuMP.backend(m).optimizer.model.inner

        @test status == MOI.OPTIMAL
        @test com.best_sol == 17
        @test minimum([JuMP.value(var) for var in states]) == 17 == JuMP.value(max_color)
    end
end

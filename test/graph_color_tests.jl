@testset "Graph coloring" begin

function normal_49_states()
    com = CS.init()

    num_colors = 8
    washington = add_var!(com, 1, num_colors)
    montana = add_var!(com, 1, num_colors)
    maine = add_var!(com, 1, num_colors)
    north_dakota = add_var!(com, 1, num_colors)
    south_dakota = add_var!(com, 1, num_colors)
    wyoming = add_var!(com, 1, num_colors)
    wisconsin = add_var!(com, 1, num_colors)
    idaho = add_var!(com, 1, num_colors)
    vermont = add_var!(com, 1, num_colors)
    minnesota = add_var!(com, 1, num_colors)
    oregon = add_var!(com, 1, num_colors)
    new_hampshire = add_var!(com, 1, num_colors)
    iowa = add_var!(com, 1, num_colors)
    massachusetts = add_var!(com, 1, num_colors)
    nebraska = add_var!(com, 1, num_colors)
    new_york = add_var!(com, 1, num_colors)
    pennsylvania = add_var!(com, 1, num_colors)
    connecticut = add_var!(com, 1, num_colors)
    rhode_island = add_var!(com, 1, num_colors)
    new_jersey = add_var!(com, 1, num_colors)
    indiana = add_var!(com, 1, num_colors)
    nevada = add_var!(com, 1, num_colors)
    utah = add_var!(com, 1, num_colors)
    california = add_var!(com, 1, num_colors)
    ohio = add_var!(com, 1, num_colors)
    illinois = add_var!(com, 1, num_colors)
    washington_dc = add_var!(com, 1, num_colors)
    delaware = add_var!(com, 1, num_colors)
    west_virginia = add_var!(com, 1, num_colors)
    maryland = add_var!(com, 1, num_colors)
    colorado = add_var!(com, 1, num_colors)
    kentucky = add_var!(com, 1, num_colors)
    kansas = add_var!(com, 1, num_colors)
    virginia = add_var!(com, 1, num_colors)
    missouri = add_var!(com, 1, num_colors)
    arizona = add_var!(com, 1, num_colors)
    oklahoma = add_var!(com, 1, num_colors)
    north_carolina = add_var!(com, 1, num_colors)
    tennessee = add_var!(com, 1, num_colors)
    texas = add_var!(com, 1, num_colors)
    new_mexico = add_var!(com, 1, num_colors)
    alabama = add_var!(com, 1, num_colors)
    mississippi = add_var!(com, 1, num_colors)
    georgia = add_var!(com, 1, num_colors)
    south_carolina = add_var!(com, 1, num_colors)
    arkansas = add_var!(com, 1, num_colors)
    louisiana = add_var!(com, 1, num_colors)
    florida = add_var!(com, 1, num_colors)
    michigan = add_var!(com, 1, num_colors)

    states = [washington,montana,maine,north_dakota,south_dakota,wyoming,wisconsin,idaho,vermont,minnesota,oregon,new_hampshire,
    iowa,massachusetts,nebraska,new_york,pennsylvania,connecticut,rhode_island,new_jersey,indiana,nevada,utah,california,ohio,
    illinois,washington_dc,delaware,west_virginia,maryland,colorado,kentucky,kansas,virginia,missouri,arizona,oklahoma,north_carolina,
    tennessee,texas,new_mexico,alabama,mississippi,georgia,south_carolina,arkansas,louisiana,florida,michigan]

    add_constraint!(com, washington != oregon)
    add_constraint!(com, washington != idaho)
    add_constraint!(com, oregon != idaho)
    add_constraint!(com, oregon != nevada)
    add_constraint!(com, oregon != california)
    add_constraint!(com, california != nevada)
    add_constraint!(com, california != arizona)
    add_constraint!(com, nevada != idaho)
    add_constraint!(com, nevada != utah)
    add_constraint!(com, nevada != arizona)
    add_constraint!(com, idaho != montana)
    add_constraint!(com, idaho != wyoming)
    add_constraint!(com, idaho != utah)
    add_constraint!(com, utah != wyoming)
    add_constraint!(com, utah != colorado)
    add_constraint!(com, utah != new_mexico)
    add_constraint!(com, utah != arizona)
    add_constraint!(com, arizona != colorado)
    add_constraint!(com, arizona != new_mexico)
    add_constraint!(com, montana != north_dakota)
    add_constraint!(com, montana != south_dakota)
    add_constraint!(com, montana != wyoming)
    add_constraint!(com, wyoming != south_dakota)
    add_constraint!(com, wyoming != nebraska)
    add_constraint!(com, wyoming != colorado)
    add_constraint!(com, colorado != nebraska)
    add_constraint!(com, colorado != kansas)
    add_constraint!(com, colorado != oklahoma)
    add_constraint!(com, colorado != new_mexico)
    add_constraint!(com, new_mexico != oklahoma)
    add_constraint!(com, new_mexico != texas)
    add_constraint!(com, north_dakota != minnesota)
    add_constraint!(com, north_dakota != south_dakota)
    add_constraint!(com, south_dakota != minnesota)
    add_constraint!(com, south_dakota != iowa)
    add_constraint!(com, south_dakota != nebraska)
    add_constraint!(com, nebraska != iowa)
    add_constraint!(com, nebraska != missouri)
    add_constraint!(com, nebraska != kansas)
    add_constraint!(com, kansas != missouri)
    add_constraint!(com, kansas != oklahoma)
    add_constraint!(com, oklahoma != arkansas)
    add_constraint!(com, oklahoma != texas)
    add_constraint!(com, texas != arkansas)
    add_constraint!(com, texas != louisiana)
    add_constraint!(com, minnesota != wisconsin)
    add_constraint!(com, minnesota != iowa)
    add_constraint!(com, iowa != wisconsin)
    add_constraint!(com, iowa != illinois)
    add_constraint!(com, iowa != missouri)
    add_constraint!(com, missouri != illinois)
    add_constraint!(com, missouri != kentucky)
    add_constraint!(com, missouri != tennessee)
    add_constraint!(com, missouri != arkansas)
    add_constraint!(com, arkansas != tennessee)
    add_constraint!(com, arkansas != mississippi)
    add_constraint!(com, arkansas != louisiana)
    add_constraint!(com, louisiana != mississippi)
    add_constraint!(com, wisconsin != illinois)
    add_constraint!(com, wisconsin != michigan)
    add_constraint!(com, illinois != indiana)
    add_constraint!(com, illinois != kentucky)
    add_constraint!(com, kentucky != indiana)
    add_constraint!(com, kentucky != ohio)
    add_constraint!(com, kentucky != west_virginia)
    add_constraint!(com, kentucky != virginia)
    add_constraint!(com, kentucky != tennessee)
    add_constraint!(com, tennessee != virginia)
    add_constraint!(com, tennessee != north_carolina)
    add_constraint!(com, tennessee != georgia)
    add_constraint!(com, tennessee != alabama)
    add_constraint!(com, tennessee != mississippi)
    add_constraint!(com, mississippi != alabama)
    add_constraint!(com, michigan != indiana)
    add_constraint!(com, michigan != ohio)
    add_constraint!(com, indiana != ohio)
    add_constraint!(com, alabama != georgia)
    add_constraint!(com, alabama != florida)
    add_constraint!(com, ohio != pennsylvania)
    add_constraint!(com, ohio != west_virginia)
    add_constraint!(com, maine != new_hampshire)
    add_constraint!(com, new_hampshire != vermont)
    add_constraint!(com, new_hampshire != massachusetts)
    add_constraint!(com, vermont != massachusetts)
    add_constraint!(com, vermont != new_york)
    add_constraint!(com, massachusetts != new_york)
    add_constraint!(com, massachusetts != rhode_island)
    add_constraint!(com, massachusetts != connecticut)
    add_constraint!(com, connecticut != rhode_island)
    add_constraint!(com, new_york != connecticut)
    add_constraint!(com, new_york != pennsylvania)
    add_constraint!(com, new_york != new_jersey)
    add_constraint!(com, pennsylvania != new_jersey)
    add_constraint!(com, pennsylvania != delaware)
    add_constraint!(com, pennsylvania != maryland)
    add_constraint!(com, pennsylvania != west_virginia)
    add_constraint!(com, new_jersey != delaware)
    add_constraint!(com, maryland != washington_dc)
    add_constraint!(com, maryland != west_virginia)
    add_constraint!(com, maryland != virginia)
    add_constraint!(com, washington_dc != virginia)
    add_constraint!(com, west_virginia != virginia)
    add_constraint!(com, virginia != north_carolina)
    add_constraint!(com, north_carolina != south_carolina)
    add_constraint!(com, south_carolina != georgia)
    add_constraint!(com, georgia != florida)

    # :should be :Min or :Max
    @test_throws ErrorException set_objective!(com, :Minimize, CS.vars_max(states))

    set_objective!(com, :Min, CS.vars_max(states))

    status = solve!(com; keep_logs=true)
    CS.save_logs(com, "graph_color_optimize.json")
    rm("graph_color_optimize.json")

    @test status == :Solved
    @test com.best_sol == 4
    @test all([CS.isfixed(var) for var in states])
    @test maximum([CS.value(var) for var in states]) == 4

    return com
end

@testset "49 US states + DC" begin
    com1 = normal_49_states()
    com2 = normal_49_states()
    info_1 = com1.info
    info_2 = com2.info
    @test info_1.pre_backtrack_calls == info_2.pre_backtrack_calls
    @test info_1.backtrack_fixes == info_2.backtrack_fixes
    @test info_1.in_backtrack_calls == info_2.in_backtrack_calls
    @test info_1.backtrack_reverses == info_2.backtrack_reverses
    logs_1 = CS.get_logs(com1)
    logs_2 = CS.get_logs(com2)
    @test CS.same_logs(logs_1[:tree], logs_2[:tree])
end

@testset "49 US states + DC without sorting" begin
    com = CS.init()

    num_colors = 8
    washington = add_var!(com, 1, num_colors)
    montana = add_var!(com, 1, num_colors)
    maine = add_var!(com, 1, num_colors)
    north_dakota = add_var!(com, 1, num_colors)
    south_dakota = add_var!(com, 1, num_colors)
    wyoming = add_var!(com, 1, num_colors)
    wisconsin = add_var!(com, 1, num_colors)
    idaho = add_var!(com, 1, num_colors)
    vermont = add_var!(com, 1, num_colors)
    minnesota = add_var!(com, 1, num_colors)
    oregon = add_var!(com, 1, num_colors)
    new_hampshire = add_var!(com, 1, num_colors)
    iowa = add_var!(com, 1, num_colors)
    massachusetts = add_var!(com, 1, num_colors)
    nebraska = add_var!(com, 1, num_colors)
    new_york = add_var!(com, 1, num_colors)
    pennsylvania = add_var!(com, 1, num_colors)
    connecticut = add_var!(com, 1, num_colors)
    rhode_island = add_var!(com, 1, num_colors)
    new_jersey = add_var!(com, 1, num_colors)
    indiana = add_var!(com, 1, num_colors)
    nevada = add_var!(com, 1, num_colors)
    utah = add_var!(com, 1, num_colors)
    california = add_var!(com, 1, num_colors)
    ohio = add_var!(com, 1, num_colors)
    illinois = add_var!(com, 1, num_colors)
    washington_dc = add_var!(com, 1, num_colors)
    delaware = add_var!(com, 1, num_colors)
    west_virginia = add_var!(com, 1, num_colors)
    maryland = add_var!(com, 1, num_colors)
    colorado = add_var!(com, 1, num_colors)
    kentucky = add_var!(com, 1, num_colors)
    kansas = add_var!(com, 1, num_colors)
    virginia = add_var!(com, 1, num_colors)
    missouri = add_var!(com, 1, num_colors)
    arizona = add_var!(com, 1, num_colors)
    oklahoma = add_var!(com, 1, num_colors)
    north_carolina = add_var!(com, 1, num_colors)
    tennessee = add_var!(com, 1, num_colors)
    texas = add_var!(com, 1, num_colors)
    new_mexico = add_var!(com, 1, num_colors)
    alabama = add_var!(com, 1, num_colors)
    mississippi = add_var!(com, 1, num_colors)
    georgia = add_var!(com, 1, num_colors)
    south_carolina = add_var!(com, 1, num_colors)
    arkansas = add_var!(com, 1, num_colors)
    louisiana = add_var!(com, 1, num_colors)
    florida = add_var!(com, 1, num_colors)
    michigan = add_var!(com, 1, num_colors)

    states = [washington,montana,maine,north_dakota,south_dakota,wyoming,wisconsin,idaho,vermont,minnesota,oregon,new_hampshire,
    iowa,massachusetts,nebraska,new_york,pennsylvania,connecticut,rhode_island,new_jersey,indiana,nevada,utah,california,ohio,
    illinois,washington_dc,delaware,west_virginia,maryland,colorado,kentucky,kansas,virginia,missouri,arizona,oklahoma,north_carolina,
    tennessee,texas,new_mexico,alabama,mississippi,georgia,south_carolina,arkansas,louisiana,florida,michigan]

    add_constraint!(com, washington != oregon)
    add_constraint!(com, washington != idaho)
    add_constraint!(com, oregon != idaho)
    add_constraint!(com, oregon != nevada)
    add_constraint!(com, oregon != california)
    add_constraint!(com, california != nevada)
    add_constraint!(com, california != arizona)
    add_constraint!(com, nevada != idaho)
    add_constraint!(com, nevada != utah)
    add_constraint!(com, nevada != arizona)
    add_constraint!(com, idaho != montana)
    add_constraint!(com, idaho != wyoming)
    add_constraint!(com, idaho != utah)
    add_constraint!(com, utah != wyoming)
    add_constraint!(com, utah != colorado)
    add_constraint!(com, utah != new_mexico)
    add_constraint!(com, utah != arizona)
    add_constraint!(com, arizona != colorado)
    add_constraint!(com, arizona != new_mexico)
    add_constraint!(com, montana != north_dakota)
    add_constraint!(com, montana != south_dakota)
    add_constraint!(com, montana != wyoming)
    add_constraint!(com, wyoming != south_dakota)
    add_constraint!(com, wyoming != nebraska)
    add_constraint!(com, wyoming != colorado)
    add_constraint!(com, colorado != nebraska)
    add_constraint!(com, colorado != kansas)
    add_constraint!(com, colorado != oklahoma)
    add_constraint!(com, colorado != new_mexico)
    add_constraint!(com, new_mexico != oklahoma)
    add_constraint!(com, new_mexico != texas)
    add_constraint!(com, north_dakota != minnesota)
    add_constraint!(com, north_dakota != south_dakota)
    add_constraint!(com, south_dakota != minnesota)
    add_constraint!(com, south_dakota != iowa)
    add_constraint!(com, south_dakota != nebraska)
    add_constraint!(com, nebraska != iowa)
    add_constraint!(com, nebraska != missouri)
    add_constraint!(com, nebraska != kansas)
    add_constraint!(com, kansas != missouri)
    add_constraint!(com, kansas != oklahoma)
    add_constraint!(com, oklahoma != arkansas)
    add_constraint!(com, oklahoma != texas)
    add_constraint!(com, texas != arkansas)
    add_constraint!(com, texas != louisiana)
    add_constraint!(com, minnesota != wisconsin)
    add_constraint!(com, minnesota != iowa)
    add_constraint!(com, iowa != wisconsin)
    add_constraint!(com, iowa != illinois)
    add_constraint!(com, iowa != missouri)
    add_constraint!(com, missouri != illinois)
    add_constraint!(com, missouri != kentucky)
    add_constraint!(com, missouri != tennessee)
    add_constraint!(com, missouri != arkansas)
    add_constraint!(com, arkansas != tennessee)
    add_constraint!(com, arkansas != mississippi)
    add_constraint!(com, arkansas != louisiana)
    add_constraint!(com, louisiana != mississippi)
    add_constraint!(com, wisconsin != illinois)
    add_constraint!(com, wisconsin != michigan)
    add_constraint!(com, illinois != indiana)
    add_constraint!(com, illinois != kentucky)
    add_constraint!(com, kentucky != indiana)
    add_constraint!(com, kentucky != ohio)
    add_constraint!(com, kentucky != west_virginia)
    add_constraint!(com, kentucky != virginia)
    add_constraint!(com, kentucky != tennessee)
    add_constraint!(com, tennessee != virginia)
    add_constraint!(com, tennessee != north_carolina)
    add_constraint!(com, tennessee != georgia)
    add_constraint!(com, tennessee != alabama)
    add_constraint!(com, tennessee != mississippi)
    add_constraint!(com, mississippi != alabama)
    add_constraint!(com, michigan != indiana)
    add_constraint!(com, michigan != ohio)
    add_constraint!(com, indiana != ohio)
    add_constraint!(com, alabama != georgia)
    add_constraint!(com, alabama != florida)
    add_constraint!(com, ohio != pennsylvania)
    add_constraint!(com, ohio != west_virginia)
    add_constraint!(com, maine != new_hampshire)
    add_constraint!(com, new_hampshire != vermont)
    add_constraint!(com, new_hampshire != massachusetts)
    add_constraint!(com, vermont != massachusetts)
    add_constraint!(com, vermont != new_york)
    add_constraint!(com, massachusetts != new_york)
    add_constraint!(com, massachusetts != rhode_island)
    add_constraint!(com, massachusetts != connecticut)
    add_constraint!(com, connecticut != rhode_island)
    add_constraint!(com, new_york != connecticut)
    add_constraint!(com, new_york != pennsylvania)
    add_constraint!(com, new_york != new_jersey)
    add_constraint!(com, pennsylvania != new_jersey)
    add_constraint!(com, pennsylvania != delaware)
    add_constraint!(com, pennsylvania != maryland)
    add_constraint!(com, pennsylvania != west_virginia)
    add_constraint!(com, new_jersey != delaware)
    add_constraint!(com, maryland != washington_dc)
    add_constraint!(com, maryland != west_virginia)
    add_constraint!(com, maryland != virginia)
    add_constraint!(com, washington_dc != virginia)
    add_constraint!(com, west_virginia != virginia)
    add_constraint!(com, virginia != north_carolina)
    add_constraint!(com, north_carolina != south_carolina)
    add_constraint!(com, south_carolina != georgia)
    add_constraint!(com, georgia != florida)

    # :should be :Min or :Max
    @test_throws ErrorException set_objective!(com, :Minimize, CS.vars_max(states))

    set_objective!(com, :Min, CS.vars_max(states))

    status = solve!(com; keep_logs=true, backtrack_sorting=false)
    CS.save_logs(com, "graph_color_optimize.json")
    rm("graph_color_optimize.json")

    @test status == :Solved
    @test com.best_sol == 4
    @test all([CS.isfixed(var) for var in states])
    @test maximum([CS.value(var) for var in states]) == 4

end

@testset "49 US states + DC only 3 colors" begin
    m = Model(with_optimizer(CS.Optimizer))

    num_colors = 3
    @variable(m, 1 <= washington <= num_colors, Int)
    @variable(m, 1 <= montana <= num_colors, Int)
    @variable(m, 1 <= maine <= num_colors, Int)
    @variable(m, 1 <= north_dakota <= num_colors, Int)
    @variable(m, 1 <= south_dakota <= num_colors, Int)
    @variable(m, 1 <= wyoming <= num_colors, Int)
    @variable(m, 1 <= wisconsin <= num_colors, Int)
    @variable(m, 1 <= idaho <= num_colors, Int)
    @variable(m, 1 <= vermont <= num_colors, Int)
    @variable(m, 1 <= minnesota <= num_colors, Int)
    @variable(m, 1 <= oregon <= num_colors, Int)
    @variable(m, 1 <= new_hampshire <= num_colors, Int)
    @variable(m, 1 <= iowa <= num_colors, Int)
    @variable(m, 1 <= massachusetts <= num_colors, Int)
    @variable(m, 1 <= nebraska <= num_colors, Int)
    @variable(m, 1 <= new_york <= num_colors, Int)
    @variable(m, 1 <= pennsylvania <= num_colors, Int)
    @variable(m, 1 <= connecticut <= num_colors, Int)
    @variable(m, 1 <= rhode_island <= num_colors, Int)
    @variable(m, 1 <= new_jersey <= num_colors, Int)
    @variable(m, 1 <= indiana <= num_colors, Int)
    @variable(m, 1 <= nevada <= num_colors, Int)
    @variable(m, 1 <= utah <= num_colors, Int)
    @variable(m, 1 <= california <= num_colors, Int)
    @variable(m, 1 <= ohio <= num_colors, Int)
    @variable(m, 1 <= illinois <= num_colors, Int)
    @variable(m, 1 <= washington_dc <= num_colors, Int)
    @variable(m, 1 <= delaware <= num_colors, Int)
    @variable(m, 1 <= west_virginia <= num_colors, Int)
    @variable(m, 1 <= maryland <= num_colors, Int)
    @variable(m, 1 <= colorado <= num_colors, Int)
    @variable(m, 1 <= kentucky <= num_colors, Int)
    @variable(m, 1 <= kansas <= num_colors, Int)
    @variable(m, 1 <= virginia <= num_colors, Int)
    @variable(m, 1 <= missouri <= num_colors, Int)
    @variable(m, 1 <= arizona <= num_colors, Int)
    @variable(m, 1 <= oklahoma <= num_colors, Int)
    @variable(m, 1 <= north_carolina <= num_colors, Int)
    @variable(m, 1 <= tennessee <= num_colors, Int)
    @variable(m, 1 <= texas <= num_colors, Int)
    @variable(m, 1 <= new_mexico <= num_colors, Int)
    @variable(m, 1 <= alabama <= num_colors, Int)
    @variable(m, 1 <= mississippi <= num_colors, Int)
    @variable(m, 1 <= georgia <= num_colors, Int)
    @variable(m, 1 <= south_carolina <= num_colors, Int)
    @variable(m, 1 <= arkansas <= num_colors, Int)
    @variable(m, 1 <= louisiana <= num_colors, Int)
    @variable(m, 1 <= florida <= num_colors, Int)
    @variable(m, 1 <= michigan <= num_colors, Int)

    states = [washington,montana,maine,north_dakota,south_dakota,wyoming,wisconsin,idaho,vermont,minnesota,oregon,new_hampshire,
    iowa,massachusetts,nebraska,new_york,pennsylvania,connecticut,rhode_island,new_jersey,indiana,nevada,utah,california,ohio,
    illinois,washington_dc,delaware,west_virginia,maryland,colorado,kentucky,kansas,virginia,missouri,arizona,oklahoma,north_carolina,
    tennessee,texas,new_mexico,alabama,mississippi,georgia,south_carolina,arkansas,louisiana,florida,michigan]

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

end
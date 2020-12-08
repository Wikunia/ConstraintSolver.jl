function solve_us_graph_coloring(;num_colors=8, equality=false)
    m = Model(optimizer_with_attributes(
        CS.Optimizer,
        "logging" => [],
        "branch_strategy" => :OLD,
        "seed"=>1
    ))
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
    if equality
        @constraint(m, [california, new_york, florida] in CS.EqualSet())
        @constraint(m, [maryland, alabama, wisconsin, south_carolina] in CS.EqualSet())
    end

    @constraint(m, max_color .>= states)
    @objective(m, Min, max_color)

    optimize!(m)

    status = JuMP.termination_status(m)
    if num_colors >= 4
        @assert status == MOI.OPTIMAL
        @assert JuMP.objective_value(m) ≈ 4
    else
        @assert status == MOI.INFEASIBLE
    end
end

function color_graph(filename, correct_num_colors; time_limit = 100, logging = [])
    m = Model(optimizer_with_attributes(
        CS.Optimizer,
        "time_limit" => time_limit,
        "logging" => logging,
    ))

    lines = readlines(filename)
    num_colors = 0
    x = nothing
    max_color = nothing
    degrees = nothing
    for line in lines
        parts = split(line, " ")
        if parts[1] == "p"
            num_colors = parse(Int, parts[3])
            @variable(m, 1 <= max_color <= num_colors, Int)
            @variable(m, 1 <= x[1:num_colors] <= num_colors, Int)
            degrees = zeros(Int, num_colors)
        elseif parts[1] == "e"
            f = parse(Int, parts[2])
            t = parse(Int, parts[3])
            @constraint(m, x[f] != x[t])
            degrees[f] += 1
            degrees[t] += 1
        end
    end
    max_degree = maximum(degrees)

    @constraint(m, max_color <= max_degree)

    @constraint(m, max_color .>= x)
    @objective(m, Min, max_color)

    optimize!(m)

    status = JuMP.termination_status(m)

    @assert status == MOI.OPTIMAL
    @assert JuMP.objective_value(m) ≈ correct_num_colors
end

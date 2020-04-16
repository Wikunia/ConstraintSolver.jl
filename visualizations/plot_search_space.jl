using Plots
rectangle(w, h, x, y) = Shape(x .+ [0, w, w, 0], y .+ [0, 0, h, h])

function plot_search_space(grid, com_grid, fname)

    plot(
        0:9,
        0:9,
        size = (500, 500),
        legend = false,
        xaxis = false,
        yaxis = false,
        aspect_ratio = :equal,
    )
    for i = 0:8, j = 0:8
        plot!(rectangle(1, 1, i, j), color = :white)
    end
    for i in [3, 6]
        plot!([i, i], [0, 9], color = :black, linewidth = 4)
    end
    for j in [3, 6]
        plot!([0, 9], [j, j], color = :black, linewidth = 4)
    end

    for ind in keys(com_grid)
        if CS.isfixed(com_grid[ind])
            x = ind[2] - 0.5
            y = 10 - ind[1] - 0.5
            if grid[ind] != 0
                annotate!([x, y, text(string(CS.value(com_grid[ind])), 20, :black)])
            else
                annotate!([x, y, text(string(CS.value(com_grid[ind])), 20, :blue)])
            end
        else
            vals = CS.values(com_grid[ind])
            sort!(vals)
            x = ind[2] - 0.5
            y = 10 - ind[1] - 0.2
            max_idx = min(3, length(vals))
            text_vals = join(vals[1:max_idx], ",")
            annotate!([x, y, text(text_vals, 7)])
            if length(vals) > 3
                y -= 0.25
                max_idx = min(6, length(vals))
                text_vals = join(vals[4:max_idx], ",")
                annotate!([x, y, text(text_vals, 7)])
            end
            if length(vals) > 6
                y -= 0.25
                max_idx = length(vals)
                text_vals = join(vals[7:max_idx], ",")
                annotate!([x, y, text(text_vals, 7)])
            end

        end
    end
    if fname != ""
        png("visualizations/images/$(fname)")
    end
end

function plot_killer(grid, sums, fname; fill = true, mark = nothing)
    plot(;
        size = (900, 900),
        legend = false,
        xaxis = false,
        yaxis = false,
        aspect_ratio = :equal,
    )
    for s in sums
        ind = s.indices[1]
        x = ind[2] - 0.75
        y = 10 - ind[1] - 0.17
        annotate!(x, y, text(s.result, 15, :black))
        if mark === nothing
            for ind in s.indices
                plot!(rectangle(1, 1, ind[2] - 1, 9 - ind[1]), color = s.color, alpha = 0.4)
            end
        else
            for ind in s.indices
                if ind in mark
                    plot!(
                        rectangle(1, 1, ind[2] - 1, 9 - ind[1]),
                        color = "red",
                        alpha = 0.4,
                    )
                else
                    plot!(
                        rectangle(1, 1, ind[2] - 1, 9 - ind[1]),
                        color = s.color,
                        alpha = 0.4,
                    )
                end
            end
        end
    end

    for i in [3, 6]
        plot!([i, i], [0, 9], color = :black, linewidth = 4)
    end
    for j in [3, 6]
        plot!([0, 9], [j, j], color = :black, linewidth = 4)
    end


    if fill
        for ind in keys(grid)
            if CS.isfixed(grid[ind])
                x = ind[2] - 0.5
                y = 10 - ind[1] - 0.5
                annotate!(x, y, text(value(grid[ind]), 20, :black))
            else
                vals = values(grid[ind])
                sort!(vals)
                x = ind[2] - 0.3
                y = 10 - ind[1] - 0.2
                max_idx = min(3, length(vals))
                text_vals = join(vals[1:max_idx], ",")
                annotate!(x, y, text(text_vals, 11))
                if length(vals) > 3
                    y -= 0.25
                    max_idx = min(6, length(vals))
                    text_vals = join(vals[4:max_idx], ",")
                    annotate!(x, y, text(text_vals, 11))
                end
                if length(vals) > 6
                    y -= 0.25
                    max_idx = length(vals)
                    text_vals = join(vals[7:max_idx], ",")
                    annotate!(x, y, text(text_vals, 11))
                end

            end
        end
    end

    png("/home/ole/Julia/ConstraintSolver/visualizations/images/$(fname)")
end

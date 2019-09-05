function plot_search_space(com, grid, fname)
    rectangle(w, h, x, y) = Shape(x .+ [0,w,w,0], y .+ [0,0,h,h])

    plot(0:9,0:9, size=(500,500), legend=false, xaxis=false, yaxis=false, aspect_ratio=:equal)
    for i=0:8, j=0:8
        plot!(rectangle(1,1,i,j), color=:white)
    end
    for i=[3,6]
        plot!([i,i],[0,9], color=:black, linewidth=4)
    end
    for j=[3,6]
        plot!([0,9],[j,j], color=:black, linewidth=4)
    end

    for ind in keys(com.grid)
        if com.grid[ind] != com.not_val
            x = ind[2]-0.5
            y = 10-ind[1]-0.5
            if grid[ind] != com.not_val
                annotate!(x, y, text(com.grid[ind],20, :black))
            else
                annotate!(x, y, text(com.grid[ind],20, :blue))
            end
        else
            vals = collect(keys(com.search_space[ind]))
            sort!(vals)
            x = ind[2]-0.5
            y = 10-ind[1]-0.2
            max_idx = min(3, length(vals))
            text_vals = join(vals[1:max_idx],",")
            annotate!(x, y, text(text_vals,7))
            if length(vals) > 3
                y -= 0.25
                max_idx = min(6, length(vals))
                text_vals = join(vals[4:max_idx],",")
                annotate!(x, y, text(text_vals,7))
            end
            if length(vals) > 6
                y -= 0.25
                max_idx = length(vals)
                text_vals = join(vals[7:max_idx],",")
                annotate!(x, y, text(text_vals,7))
            end

        end
    end

    png("visualizations/$(fname)")
end
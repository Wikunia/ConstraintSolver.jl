# convert folders in results into single csvs
# if the last line is not a result line => ignored
using DataFrames, CSV

function create_csv()
    root_dir = "graph_color/results"
    max_time = 1800


    for dir in readdir(root_dir)
        !isdir(dir) && continue
        df = DataFrame("instance"=>String[],
            "status"=>String[], "result"=>Float64[], "time"=>Float64[])
        for (root, dirs, files) in walkdir(joinpath(root_dir, dir))
            pnames = joinpath.(root, files) # files is a Vector{String}, can be empty
            for pname in pnames
                parts = split(pname, "/")
                if parts[end] == "stdout"
                    instance = parts[end-1]
                    lines = readlines(pname)
                    isempty(lines) && continue
                    result = lines[end]
                    result_parts = split(result, ", ")
                    length(result_parts) != 3 && continue
                    status, result_str, time_str = result_parts
                    result = parse(Float64, result_str)
                    time = parse(Float64, time_str)
                    push!(df, (instance, status, result, time))
                end
            end
            CSV.write(joinpath(root_dir, "$dir.csv"), df)
        end
    end
end

create_csv()

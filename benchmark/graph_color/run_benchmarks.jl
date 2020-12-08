
#!/usr/bin/env julia

using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--file", "-f"
        help = "col file to run"
        arg_type = String
        required = true
        "--time_limit", "-t"
        help = "Target commit id or branch"
        arg_type = Int
        default = 1800
    end

    return parse_args(s)
end


if isinteractive() == false
    args = parse_commandline()

    include("cs.jl")
    # for compiling
    main("/home/ole/Julia/ConstraintSolver/instances/graph_coloring/in_seconds/queen5_5.col")
    println("")
    println("======= ACTUAL RUN =======")
    println("")
    # actual run
    main(args["file"]; time_limit = args["time_limit"])
end

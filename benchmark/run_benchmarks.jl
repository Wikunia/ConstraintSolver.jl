 
#!/usr/bin/env julia

using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--base", "-b"
            help = "Baseline commit id or branch"
            arg_type = String
            default = "master"
        "--target", "-t"
            help = "Target commit id or branch"
            arg_type = String
            required = true
        "--pr"
            help = "ID of the PR to comment on"
            arg_type = Int
    end

    return parse_args(s)
end


if isinteractive() == false
    args = parse_commandline()
    using PkgBenchmark
    using ConstraintSolver
    using GitHub, JSON

    github_auth = GitHub.authenticate(ENV["GITHUB_AUTH"])
    target = args["target"]
    base = args["base"]

    baseline_config = BenchmarkConfig(id = base, juliacmd = `julia -O3`)
    target_config = BenchmarkConfig(id = target, juliacmd = `julia -O3`)
    
    judged = judge("ConstraintSolver", target_config, baseline_config)
    
    markdown = sprint(export_markdown, judged)
    if args["pr"] !== nothing
        comment = create_comment("Wikunia/ConstraintSolver.jl", PullRequest(args["pr"]), markdown; auth=github_auth)
        println("Comment id: $(comment.id)")
    end
end



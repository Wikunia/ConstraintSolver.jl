 
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
        "--comment", "-c"
            help = "ID of the comment you want to update"
            arg_type = Int
        "--file", "-f"
            help = "Markdown filename"
            arg_type = String
    end

    return parse_args(s)
end


if isinteractive() == false
    args = parse_commandline()
    using PkgBenchmark
    using ConstraintSolver, Cbc
    using GitHub, JSON, Statistics

    github_auth = GitHub.authenticate(ENV["GITHUB_AUTH"])
    target = args["target"]
    base = args["base"]

    baseline_config = BenchmarkConfig(id = base, juliacmd = `julia -O3`)
    target_config = BenchmarkConfig(id = target, juliacmd = `julia -O3`)
    
    judged = judge("ConstraintSolver", target_config, baseline_config; f=median)
    
    markdown = sprint(export_markdown, judged)
    if args["file"] !== nothing
        export_markdown(args["file"], judged)
    end
    if args["comment"] !== nothing
        comment = edit_comment("Wikunia/ConstraintSolver.jl", Comment(args["comment"]), :pr; params = Dict(
            :body => markdown
        ), auth=github_auth)
        println("Updated comment: $(comment.html_url)")
    elseif args["pr"] !== nothing
        comment = create_comment("Wikunia/ConstraintSolver.jl", PullRequest(args["pr"]), markdown; auth=github_auth)
        println("New comment: $(comment.html_url)")
    end
end
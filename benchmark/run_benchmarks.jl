 
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
    
    gist_json = JSON.parse(
        """
        {
        "description": "ConstraintSolver $target vs $base",
        "public": false,
        "files": {
            "benchmark.md": {
            "content": "$(escape_string(sprint(export_markdown, judged)))"
            }
        }
        }
        """
    )

    export_markdown(joinpath(pkgdir(ConstraintSolver), "benchmark/results/$target-$base.md"), judged)
    
    posted_gist = create_gist(params = gist_json; auth=github_auth);
    url = get(posted_gist.html_url)
    println("Gist url: $url")
end



# Tests that every option is documented
@testset "Documentation" begin
    @testset "Options" begin
        cwd = pwd()
        dir = pathof(ConstraintSolver)[1:end-20]
        cd(dir)
        cd("../docs/src")
        options_md = readlines("options.md")
        all_options = fieldnames(CS.SolverOptions)
        found_all = true
        for option in all_options
            found = false
            option_str = String(option)
            for line in options_md
                if startswith(line, "## `$option_str`")
                    found = true
                    break
                end
            end
            if !found
                found_all = false
                @error "Option $option is not documented"
            end
        end
        @test found_all

        cd(cwd)
    end
end

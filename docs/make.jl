using Documenter
using ConstraintSolver
using JuMP

makedocs(
    # See https://github.com/JuliaDocs/Documenter.jl/issues/868
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    strict = true,
    sitename = "ConstraintSolver",
    pages = [
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "How-To" => "how_to.md",
        "Solver options" => "options.md",
        "Explanation" => "explanation.md",
        "Reference" => "reference.md",
#        "Developer" => [],
#        "Library" => "library.md"
    ]
)

deploydocs(
    repo = "github.com/Wikunia/ConstraintSolver.jl.git",
)

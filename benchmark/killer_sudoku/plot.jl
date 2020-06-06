using Plots
using ConstraintSolver
dir = pkgdir(ConstraintSolver)

x = [
    "niallsudoku_5500",
    "niallsudoku_5501",
    "niallsudoku_5502",
    "niallsudoku_5503",
    "niallsudoku_6417",
    "niallsudoku_6249",
];

plot(;xaxis=("Problem"), yaxis=("Time in s"), title="Killer sudoku special")
cs_010 = [0.73, 3.69, 0.16, 0.066, 0.13, 0.06]
plot!(x, cs_010, label="CS v0.1.0", color=:red, seriestype=:scatter)
cs_017 = [0.607, 1.602, 0.173, 0.08, 0.27, 0.09]
plot!(x, cs_017, label="CS v0.1.7", color=:orange, seriestype=:scatter)
or = [2.82, 1.67, 0.46, 0.74, 0.17, 0.17];
plot!(x, or, label="OR-Tools", color=:black, seriestype=:scatter)

savefig(joinpath(dir, "benchmark/results/killer_sudoku_special/plots/current.png"))


plot(;xaxis=("Problem"), yaxis=("Time in s"), title="Killer sudoku normal rules")
cs_010 = [0.16, 0.39, 0.09, 0.39, 0.30, 0.05]
plot!(x, cs_010, label="CS v0.1.0", color=:red, seriestype=:scatter)
cs_017 = [0.096, 0.50, 0.095, 0.50, 0.48, 0.06]
plot!(x, cs_017, label="CS v0.1.7", color=:orange, seriestype=:scatter)
or = [1.18, 1.64, 0.37, 1.07, 0.04, 0.04];
plot!(x, or, label="OR-Tools", color=:black, seriestype=:scatter)

savefig(joinpath(dir, "benchmark/results/killer_sudoku/plots/current.png"))
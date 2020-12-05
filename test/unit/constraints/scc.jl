@testset "scc graph wikipedia" begin
    n = 8
    scc_init = CS.SCCInit(
        zeros(Int, n + 1),
        zeros(Int, n),
        zeros(Int, n),
        zeros(Bool, n),
        zeros(Int, n)
    )
    di_ei = [1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 8]
    di_ej = [2, 2, 3, 5, 7, 4, 3, 8, 6, 1, 7, 6, 4, 7]
    scc_map = CS.scc(di_ei, di_ej, scc_init)
    @test scc_map[1] == scc_map[2] == scc_map[5]
    @test scc_map[3] == scc_map[4] == scc_map[8]
    @test scc_map[6] == scc_map[7]
    @test scc_map[1] != scc_map[3]
    @test scc_map[1] != scc_map[6]
    @test scc_map[3] != scc_map[6]
end

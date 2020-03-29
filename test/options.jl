@testset "Options" begin
    cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
    @test_logs (:error, r"Possible values are") Model(optimizer_with_attributes(
        CS.Optimizer,
        "lp_optimizer" => cbc_optimizer,
        "logging" => [],
        "traverse_strategy" => :KFS
    ))    
end
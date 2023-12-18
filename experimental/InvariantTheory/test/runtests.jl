@testset "Invariant Theory of SL_m" begin
    S, z = polynomial_ring(QQ, "z"=> (1:2, 1:2))
    G = reductive_group(:SL,2,S)
    rep1 = representation_on_forms(G,2)
    @test ncols(representation_matrix(rep1)) == 3

    R_rep1 = invariant_ring(rep1)
    FI_rep1 = fundamental_invariants(R_rep1)
    @test length(FI_rep1) == 1

    #same rep mat as in rep1, only without multinomial coefficients.
    M = matrix(S,3,3,[z[1,1]^2 z[1,1]*z[2,1] z[2,1]^2 ; 2*z[1,1]*z[1,2] z[1,1]*z[2,2] + z[2,1]*z[1,2] 2*z[2,1]*z[2,2]; z[1,2]^2 z[1,2]*z[2,2] z[2,2]^2])
    rep2 = representation_reductive_group(G, M)
    R_rep2 = invariant_ring(rep2,R_rep1.poly_ring)
    FI_rep2 = fundamental_invariants(R_rep2) 
    x = gens(R_rep1.poly_ring)
    @test FI_rep2 == [-4*x[1]*x[3] + x[2]^2]

    #ternary cubics
    T, X = polynomial_ring(QQ, "X"=>1:10)
    g = reductive_group(:SL, 3, QQ)
    rep3 = representation_on_forms(g, 3)
    R_rep3 = invariant_ring(rep3, T)
    f = X[1]*X[4]*X[8]*X[10] - X[1]*X[4]*X[9]^2 - X[1]*X[5]*X[7]*X[10] + X[1]*X[5]*X[8]*X[9] + X[1]*X[6]*X[7]*X[9] - X[1]*X[6]*X[8]^2 - X[2]^2*X[8]*X[10] + X[2]^2*X[9]^2 + X[2]*X[3]*X[7]*X[10] - X[2]*X[3]*X[8]*X[9] + X[2]*X[4]*X[5]*X[10] - X[2]*X[4]*X[6]*X[9] - 2*X[2]*X[5]^2*X[9] + 3*X[2]*X[5]*X[6]*X[8] - X[2]*X[6]^2*X[7] - X[3]^2*X[7]*X[9] + X[3]^2*X[8]^2 - X[3]*X[4]^2*X[10] + 3*X[3]*X[4]*X[5]*X[9] - X[3]*X[4]*X[6]*X[8] - 2*X[3]*X[5]^2*X[8] + X[3]*X[5]*X[6]*X[7] + X[4]^2*X[6]^2 - 2*X[4]*X[5]^2*X[6] + X[5]^4
    @test reynolds_operator(R_rep3, f) == f

    #tori
    #example in the derksen book
    T = reductive_group(:torus, 1, QQ)
    r = representation_on_weights(T, [-3, -1, 1, 2])
    I = invariant_ring(r)
    f = fundamental_invariants(I)
    @test length(f) == 6
end

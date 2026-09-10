using CapacityEquilibria
using LinearAlgebra
using Test
import NLPModels
import MPCCModels

# The Phase 0 smoke test. Its job is to fail here, on a problem whose answer is known by
# hand, rather than later inside a model where a solver problem and a modelling problem
# look identical.
#
#   M = [2 1; 1 2],  q = [-4, 1]
#
# At x = (2, 0): F = (0, 3). x₁ > 0 with F₁ = 0, and x₂ = 0 with F₂ > 0 — so both branches
# of the complementarity are active, which a problem with an interior solution would not
# exercise. Unique, non-degenerate, and checkable without a solver.
#
# Phase 2 added the direct route (lcp_mpcc): the same LCP as an MPCCModel built without
# JuMP, which is how CCOpt's penalty method is reached. The testsets below run the same
# problem through all four backends and hold them to the same criterion.

const M = [2.0 1.0; 1.0 2.0]
const Q = [-4.0, 1.0]
const X_STAR = [2.0, 0.0]
const TOL = 1e-6
const BACKENDS = (:path, :ccopt, :ccopt_relaxation, :ccopt_penalty)

build() = lcp_model(M, Q)

@testset "CapacityEquilibria" begin

    @testset "lcp_residual is an oracle, not a report" begin
        # The known solution has zero residual, and points near it do not. If this
        # testset passes while the solver testsets fail, the solvers are wrong; if it
        # fails, nothing below it means anything.
        @test lcp_residual(M, Q, X_STAR).worst ≈ 0.0 atol = 1e-12
        @test lcp_residual(M, Q, [2.0, 1.0]).worst > 1e-3   # x₂ off its bound
        @test lcp_residual(M, Q, [1.0, 0.0]).worst > 1e-3   # F₁ ≠ 0 where x₁ > 0
        @test lcp_residual(M, Q, [-1.0, 0.0]).primal > 0.0  # x ≥ 0 violated
    end

    @testset "lcp_model rejects a non-square system" begin
        @test_throws DimensionMismatch lcp_model([1.0 2.0 3.0], [1.0, 2.0])
        @test_throws DimensionMismatch LCPVerticalModel([1.0 2.0 3.0], [1.0, 2.0])
    end

    @testset "LCPVerticalModel is the LCP, callback by callback" begin
        # The hand-written NLP underneath the direct route, checked against M and q at a
        # point with all-distinct coordinates: c(z) = w − Mx, J = [−M I], f = 0, ∇f = 0,
        # H = 0. An index slip in any callback shows up here, before a solver sees it.
        Mr = [3.0 -1.0 0.5; 2.0 4.0 -1.5; -0.5 1.0 2.5]
        qr = [1.0, -2.0, 0.5]
        nlp = LCPVerticalModel(Mr, qr)
        n = 3
        z = [0.7, -1.3, 2.1, 0.4, 1.9, -0.6]
        x, w = z[1:n], z[n+1:2n]
        @test NLPModels.get_nvar(nlp) == 2n && NLPModels.get_ncon(nlp) == n
        @test NLPModels.get_lvar(nlp) == zeros(2n) && all(isinf, NLPModels.get_uvar(nlp))
        @test NLPModels.get_lcon(nlp) == qr && NLPModels.get_ucon(nlp) == qr
        @test NLPModels.get_nlin(nlp) == n && NLPModels.get_nnln(nlp) == 0
        @test NLPModels.obj(nlp, z) == 0.0
        @test NLPModels.grad(nlp, z) == zeros(2n)
        @test NLPModels.cons(nlp, z) ≈ w - Mr * x
        @test Matrix(NLPModels.jac(nlp, z)) ≈ [-Mr Matrix(I, n, n)]
        @test NLPModels.jprod(nlp, z, z) ≈ [-Mr Matrix(I, n, n)] * z
        @test NLPModels.jtprod(nlp, z, [1.0, 2.0, 3.0]) ≈ [-Mr Matrix(I, n, n)]' * [1.0, 2.0, 3.0]
        @test NLPModels.get_nnzh(nlp) == 0
        @test NLPModels.hprod(nlp, z, [1.0, 2.0, 3.0], z) == zeros(2n)
        # The pairing the direct route declares: z[i] with z[n + i], and nothing else.
        mpcc, ix = lcp_mpcc(Mr, qr)
        @test ix == 1:n
        @test MPCCModels.get_ind_cc1(mpcc) == collect(1:n)
        @test MPCCModels.get_ind_cc2(mpcc) == collect(n+1:2n)
        @test MPCCModels.get_ncc(mpcc) == n
    end

    @testset "PATH" begin
        sol = solve_complementarity(build, :path)
        r = lcp_residual(M, Q, sol.x)
        @test r.worst < TOL          # judged on the residual, not on sol.status
        @test sol.x ≈ X_STAR atol = TOL
    end

    @testset "CCOpt (relaxation, JuMP route)" begin
        sol = solve_complementarity(build, :ccopt)
        r = lcp_residual(M, Q, sol.x)
        @test r.worst < TOL
        @test sol.x ≈ X_STAR atol = TOL
    end

    @testset "CCOpt (relaxation, direct route)" begin
        sol = solve_complementarity(M, Q, :ccopt_relaxation)
        @test lcp_residual(M, Q, sol.x).worst < TOL
        @test sol.x ≈ X_STAR atol = TOL
        @test sol.raw_status == "SOLVE_SUCCEEDED"   # recorded, not relied on
    end

    @testset "CCOpt (penalty, direct route)" begin
        # The method the JuMP route cannot reach (FINDINGS.md F-0004).
        sol = solve_complementarity(M, Q, :ccopt_penalty)
        @test lcp_residual(M, Q, sol.x).worst < TOL
        @test sol.x ≈ X_STAR atol = TOL
    end

    @testset "the four backends agree" begin
        # The question Phase 2 asks, in miniature: given the same LCP, do the routes and
        # methods land on the same point? Disagreement here is a solver or a pairing
        # question; disagreement with X_STAR above is a modelling question.
        sols = Dict(b => solve_complementarity(M, Q, b) for b in BACKENDS)
        for b in BACKENDS
            @test sols[b].x ≈ sols[:path].x atol = TOL
        end
        # The two relaxation routes are the same method on the same problem, with and
        # without the MathOptComplements bridges. They should coincide far more closely
        # than the tolerance: a gap here would mean the bridges changed the problem.
        @test sols[:ccopt].x ≈ sols[:ccopt_relaxation].x atol = 1e-12
    end

    @testset "an unknown backend is refused, and the direct backends refuse a builder" begin
        @test_throws ArgumentError solve_complementarity(build, :ipopt)
        @test_throws ArgumentError solve_complementarity(M, Q, :ipopt)
        @test_throws ArgumentError solve_complementarity(build, :ccopt_penalty)
        @test_throws ArgumentError solve_complementarity(build, :ccopt_relaxation)
    end

    @testset "PATH licence lifts the demonstration size limit" begin
        # PATHSolver falls back to a demonstration licence -- 300 variables, 2000
        # nonzeros -- when none is configured, and nothing in a small solve reveals
        # which one is in force. This builds a 400-variable LCP, which is over that
        # limit and under nothing else, so it solves if and only if a licence took.
        #
        # Without one, PATH returns OTHER_ERROR and the residual is NaN, which fails
        # the threshold below rather than passing quietly. That is checked behaviour,
        # not an assumption: both branches were run before this test was written.
        if !haskey(ENV, "PATH_LICENSE_STRING")
            @info "PATH_LICENSE_STRING not set; skipping the licence check. " *
                  "Models above 300 variables will fail until it is. See README.md."
            @test_skip false
        else
            n = 400
            Mn = Matrix(2.0I, n, n) + diagm(1 => fill(0.5, n - 1)) +
                 diagm(-1 => fill(0.5, n - 1))
            qn = [isodd(i) ? -4.0 : 1.0 for i in 1:n]
            sol = solve_complementarity(() -> lcp_model(Mn, qn), :path)
            @test lcp_residual(Mn, qn, sol.x).worst < TOL
        end
    end
end

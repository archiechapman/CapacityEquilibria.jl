using CapacityEquilibria
using LinearAlgebra
using Test

# The Phase 0 smoke test. Its job is to fail here, on a problem whose answer is known by
# hand, rather than later inside a model where a solver problem and a modelling problem
# look identical.
#
#   M = [2 1; 1 2],  q = [-4, 1]
#
# At x = (2, 0): F = (0, 3). x₁ > 0 with F₁ = 0, and x₂ = 0 with F₂ > 0 — so both branches
# of the complementarity are active, which a problem with an interior solution would not
# exercise. Unique, non-degenerate, and checkable without a solver.

const M = [2.0 1.0; 1.0 2.0]
const Q = [-4.0, 1.0]
const X_STAR = [2.0, 0.0]
const TOL = 1e-6

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
    end

    @testset "PATH" begin
        sol = solve_complementarity(build, :path)
        r = lcp_residual(M, Q, sol.x)
        @test r.worst < TOL          # judged on the residual, not on sol.status
        @test sol.x ≈ X_STAR atol = TOL
    end

    @testset "CCOpt (relaxation)" begin
        sol = solve_complementarity(build, :ccopt)
        r = lcp_residual(M, Q, sol.x)
        @test r.worst < TOL
        @test sol.x ≈ X_STAR atol = TOL
    end

    @testset "the two backends agree" begin
        # The question Phase 2 asks, in miniature: given the same builder, do the two
        # solvers land on the same point? Disagreement here is a solver question;
        # disagreement with X_STAR above is a modelling question.
        path = solve_complementarity(build, :path)
        ccopt = solve_complementarity(build, :ccopt)
        @test path.x ≈ ccopt.x atol = TOL
    end

    @testset "an unknown backend is refused" begin
        @test_throws ArgumentError solve_complementarity(build, :ipopt)
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

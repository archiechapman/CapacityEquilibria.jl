# The direct route to CCOpt: an MPCCModel built from (M, q) without JuMP, so that both of
# CCOpt's methods — relaxation and penalty — can be run on the same LCP the JuMP route
# solves. See FINDINGS.md F-0004 for why the JuMP route cannot reach the penalty method,
# and DECISIONS.md D-0004 for why the NLP underneath is hand-written.

"""
    lcp_mpcc(M, q) -> (mpcc, ix)

The LCP `0 ≤ x ⟂ Mx + q ≥ 0` as an `MPCCModels.MPCCModel` in vertical form: the NLP is
[`LCPVerticalModel`](@ref) in `z = (x, w)`, and the complementary pairs are declared by
index, `z[i] ⟂ z[n + i]`. `ix` is the range of `z` holding `x`, so that a solver's point
can be read back with `stats.solution[ix]`.

This is the pairing for the direct route, and it is the one place the two routes can
disagree by construction: on the JuMP route the pairing is `[F; x] in MOI.Complements(2n)`
(`lcp_model`), here it is two index vectors. `test/runtests.jl` checks the routes against
each other.
"""
function lcp_mpcc(M::AbstractMatrix, q::AbstractVector)
    nlp = LCPVerticalModel(Matrix{Float64}(M), Vector{Float64}(q))
    n = nlp.n
    mpcc = MPCCModels.MPCCModel(nlp, collect(1:n), collect(n + 1:2n))
    return mpcc, 1:n
end

# MadNLP's status codes, mapped onto MOI's so that a ComplementaritySolution reads the
# same whichever route produced it. Copied from CCOpt v0.1.0's MathOptInterface extension
# (`ext/CCOptMathOptInterface/CCOptMathOptInterface.jl`, `TERMINATION_STATUS`) rather than
# reached into, so that a change there does not silently change what is recorded here.
# The status is recorded and never used as the pass criterion (D-0002).
const MADNLP_TO_MOI = Dict{MadNLP.Status, MOI.TerminationStatusCode}(
    MadNLP.SOLVE_SUCCEEDED => MOI.LOCALLY_SOLVED,
    MadNLP.SOLVED_TO_ACCEPTABLE_LEVEL => MOI.ALMOST_LOCALLY_SOLVED,
    MadNLP.SEARCH_DIRECTION_BECOMES_TOO_SMALL => MOI.SLOW_PROGRESS,
    MadNLP.DIVERGING_ITERATES => MOI.INFEASIBLE_OR_UNBOUNDED,
    MadNLP.INFEASIBLE_PROBLEM_DETECTED => MOI.LOCALLY_INFEASIBLE,
    MadNLP.MAXIMUM_ITERATIONS_EXCEEDED => MOI.ITERATION_LIMIT,
    MadNLP.MAXIMUM_WALLTIME_EXCEEDED => MOI.TIME_LIMIT,
    MadNLP.INITIAL => MOI.OPTIMIZE_NOT_CALLED,
    MadNLP.RESTORATION_FAILED => MOI.NUMERICAL_ERROR,
    MadNLP.INVALID_NUMBER_DETECTED => MOI.INVALID_MODEL,
    MadNLP.ERROR_IN_STEP_COMPUTATION => MOI.NUMERICAL_ERROR,
    MadNLP.NOT_ENOUGH_DEGREES_OF_FREEDOM => MOI.INVALID_MODEL,
    MadNLP.USER_REQUESTED_STOP => MOI.INTERRUPTED,
    MadNLP.INTERNAL_ERROR => MOI.OTHER_ERROR,
    MadNLP.INVALID_NUMBER_OBJECTIVE => MOI.INVALID_MODEL,
    MadNLP.INVALID_NUMBER_GRADIENT => MOI.INVALID_MODEL,
    MadNLP.INVALID_NUMBER_CONSTRAINTS => MOI.INVALID_MODEL,
    MadNLP.INVALID_NUMBER_JACOBIAN => MOI.INVALID_MODEL,
    MadNLP.INVALID_NUMBER_HESSIAN_LAGRANGIAN => MOI.INVALID_MODEL,
)

const DIRECT_BACKENDS = (:ccopt_relaxation, :ccopt_penalty)

"""
    solve_complementarity(M, q, backend; silent = true) -> ComplementaritySolution

Solve the LCP `0 ≤ x ⟂ Mx + q ≥ 0` with `backend`, one of:

  - `:path`, `:ccopt` — the JuMP route: `lcp_model(M, q)` handed to
    `solve_complementarity(build, backend)`. `:ccopt` is CCOpt's relaxation method reached
    through the MathOptComplements bridges.
  - `:ccopt_relaxation` — CCOpt's relaxation method on the `MPCCModel` that [`lcp_mpcc`](@ref)
    builds directly. The same method as `:ccopt` with the bridges taken out, so the pair
    isolates the bridges from the method.
  - `:ccopt_penalty` — CCOpt's ℓ₁ penalty method on the same directly built model. Not
    reachable any other way (F-0004).

Both CCOpt solvers are run with their default options apart from silence, which is the
condition under which their agreement with PATH is claimed. Every returned point is to be
judged by `lcp_residual`, never by `status`.
"""
function solve_complementarity(M::AbstractMatrix, q::AbstractVector, backend::Symbol;
                               silent::Bool = true)
    if backend === :path || backend === :ccopt
        return solve_complementarity(() -> lcp_model(M, q), backend; silent = silent)
    end
    backend in DIRECT_BACKENDS || throw(ArgumentError(
        "unknown backend $backend; expected :path, :ccopt, :ccopt_relaxation or :ccopt_penalty"))
    mpcc, ix = lcp_mpcc(M, q)
    level = silent ? MadNLP.ERROR : MadNLP.INFO
    solver = if backend === :ccopt_relaxation
        CCOpt.RelaxationSolver(mpcc; solver_opts = CCOpt.RelaxationOptions(print_level = level),
                               print_level = level)
    else
        CCOpt.PenaltySolver(mpcc; solver_opts = CCOpt.PenaltyOptions{Float64}(print_level = level),
                            print_level = level)
    end
    t = @elapsed stats = CCOpt.solve_homotopy!(solver)
    return ComplementaritySolution(backend, Vector{Float64}(stats.solution[ix]),
                                   get(MADNLP_TO_MOI, stats.status, MOI.OTHER_ERROR),
                                   string(stats.status), t)
end

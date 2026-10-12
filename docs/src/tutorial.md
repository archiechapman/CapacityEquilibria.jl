# One LCP, four routes

This tutorial runs the engine on the smallest problem worth running it on: two variables
and a solution you can check with a pencil. It is the smoke test in
`test/runtests.jl`, and its job there is the same as here. It should fail on a problem
whose answer is known, rather than later, inside a model where a solver problem and a
modelling problem look the same.

Every code block below runs when the documentation is built, and the `@assert` lines are
the claims the prose makes. If one stops holding, the build fails.

## The problem, solved by hand

A linear complementarity problem asks for ``x`` with

```math
0 \le x \;\perp\; F(x) = Mx + q \ge 0,
```

meaning that for each ``i`` both ``x_i`` and ``F_i(x)`` are nonnegative and at least one of
them is zero. Take

```@example lcp
using CapacityEquilibria

M = [2.0 1.0; 1.0 2.0]
q = [-4.0, 1.0]
x_star = [2.0, 0.0]

F = M * x_star .+ q
```

At ``x^* = (2, 0)`` the map is ``F = (0, 3)``. The first pair has ``x_1 > 0`` with
``F_1 = 0``, and the second has ``x_2 = 0`` with ``F_2 > 0``. Both branches of the
complementarity are active. A problem whose solution was interior would leave the bound
branch untested, which is why this one was chosen. ``M`` is positive definite, so the
solution is unique.

## The oracle comes first

Before any solver runs, check the thing that will judge the solvers.
[`lcp_residual`](@ref) takes a point and reports how badly it fails each of the three
conditions, recomputed from the point alone:

```@example lcp
r = lcp_residual(M, q, x_star)
@assert r.worst == 0.0
r
```

Points near the answer, but wrong, are not passed:

```@example lcp
off_bound  = lcp_residual(M, q, [2.0, 1.0]).worst   # x₂ lifted off its bound
not_zero   = lcp_residual(M, q, [1.0, 0.0]).worst   # x₁ > 0 but F₁ ≠ 0
@assert off_bound > 1e-3 && not_zero > 1e-3
(off_bound, not_zero)
```

If this section failed, nothing below would mean anything. If it passes and a solver
section fails, the solver is wrong.

## PATH, through a builder

[`solve_complementarity`](@ref) does not take a model. It takes a function that builds
one, and calls it once per solver:

```@example lcp
build() = lcp_model(M, q)      # returns (model, x)

path = solve_complementarity(build, :path)
```

The reason is that a JuMP model carries one optimizer and, under CCOpt, a stack of bridges
that rewrite it. Handing the same model object to two solvers would mean the second solve
saw a model the first had already altered. A builder makes that impossible, and it also
means the two solvers cannot be given different equations, which is exactly the failure a
comparison between them exists to detect.

[`lcp_model`](@ref) writes the pairing as one constraint over one stacked vector,
`[F; x] in MOI.Complements(2n)`. `F[i]` goes with `x[i]` because they sit `n` apart in the
same vector, not because two lists happened to be built in the same order.

The point is then judged by the oracle, not by the status:

```@example lcp
@assert lcp_residual(M, q, path.x).worst < 1e-6
@assert isapprox(path.x, x_star; atol = 1e-6)
(path.x, path.status)
```

## CCOpt, through the same builder

```@example lcp
ccopt = solve_complementarity(build, :ccopt)
@assert lcp_residual(M, q, ccopt.x).worst < 1e-6
(ccopt.x, lcp_residual(M, q, ccopt.x).worst)
```

CCOpt is an interior-point solver for MPCCs, so it lands near the answer rather than on it.
The residual is of order 1e-9, against a tolerance of 1e-6 that was fixed before either
solver ran.

The `raw_status` field holds the solver's own wording of its status. For this backend it
holds an error message instead:

```@example lcp
ccopt.raw_status
```

That is a defect in CCOpt v0.1.0's MathOptInterface layer, which reads a field its
relaxation solver does not have (`FINDINGS.md` F-0007). It costs nothing here, because the
status is recorded for a reader and never used to decide anything.

## The direct route, and the penalty method

CCOpt ships two methods, a relaxation homotopy and an ℓ₁ penalty homotopy. Its JuMP layer
only ever builds the first (F-0004). To reach the second, the engine builds CCOpt's model
itself: [`LCPVerticalModel`](@ref) is the LCP as a feasibility NLP in ``z = (x, w)`` with
``w - Mx = q`` and ``x, w \ge 0``, and [`lcp_mpcc`](@ref) declares ``z_i \perp z_{n+i}`` on
top of it by index.

```@example lcp
direct  = solve_complementarity(M, q, :ccopt_relaxation)
penalty = solve_complementarity(M, q, :ccopt_penalty)

for s in (path, ccopt, direct, penalty)
    println(rpad(s.backend, 18), "residual ", lcp_residual(M, q, s.x).worst)
    @assert lcp_residual(M, q, s.x).worst < 1e-6
end
```

The two relaxation routes are the same method on the same problem, with and without the
bridges. They do not merely agree; they are the same vector:

```@example lcp
@assert ccopt.x == direct.x
ccopt.x == direct.x
```

Equality is the honest assertion here. The bridges build the same lifted NLP that
`lcp_mpcc` builds by hand, in the same variable order, and MadNLP is deterministic over it.
A tolerance would be a threshold with nothing to threshold, and if this ever fails the
bridges have changed what they construct, which is worth learning immediately.

## What a wrong pairing looks like

The complementarity pairing is where being wrong is quiet. A dimension error throws; an
infeasible problem says so; a mis-paired complementarity converges cleanly to the answer
to a different problem. On the direct route the pairing is two index vectors, so it can be
broken on purpose. Rotate the second one so that ``x_1`` is paired with ``w_2`` and ``x_2``
with ``w_1``:

```@example lcp
import MPCCModels, CCOpt, MadNLP

n = length(q)
nlp = LCPVerticalModel(M, q)
wrong = MPCCModels.MPCCModel(nlp, collect(1:n), [n + 2, n + 1])

quiet = MadNLP.ERROR
relax = CCOpt.RelaxationSolver(wrong;
    solver_opts = CCOpt.RelaxationOptions(print_level = quiet), print_level = quiet)
stats = CCOpt.solve_homotopy!(relax)
x_wrong = stats.solution[1:n]

@assert string(stats.status) == "SOLVE_SUCCEEDED"
@assert lcp_residual(M, q, x_wrong).worst > 1.0
(x_wrong, stats.status, lcp_residual(M, q, x_wrong).worst)
```

The solver reports success, and it is telling the truth. It was asked a different question
and answered it. Judged against the problem that was meant, the residual is 36, and only
the residual says so.

The penalty method, handed the same mis-paired model, behaves differently:

```@example lcp
pen = CCOpt.PenaltySolver(wrong;
    solver_opts = CCOpt.PenaltyOptions{Float64}(print_level = quiet), print_level = quiet)
pstats = CCOpt.solve_homotopy!(pen)
x_pen = pstats.solution[1:n]

@assert lcp_residual(M, q, x_pen).worst < 1e-6
(x_pen, pstats.status, lcp_residual(M, q, x_pen).worst)
```

It returns a point that solves the *intended* problem. That is a fact about this problem
and this method, and it is recorded in `FINDINGS.md` F-0008 as a warning rather than a
comfort: it means the penalty backend is not, on its own, a check on the pairing. What does
check the pairing is an assertion on the index vectors themselves, made against the model
before any solver sees it:

```@example lcp
mpcc, ix = lcp_mpcc(M, q)
@assert MPCCModels.get_ind_cc1(mpcc) == collect(1:n)
@assert MPCCModels.get_ind_cc2(mpcc) == collect(n+1:2n)
(MPCCModels.get_ind_cc1(mpcc), MPCCModels.get_ind_cc2(mpcc))
```

The test suite makes this assertion, and checks every callback of `LCPVerticalModel`
against ``M`` and ``q`` at a point with all-distinct coordinates. Three single-token
mutations of the engine source were each caught by that callback test (F-0008).

## What this tutorial does not show

It shows four routes agreeing on one easy problem: unique, nondegenerate, strictly
complementary. That is the case every method handles, and it says little about how any of
them behave where it matters. The next tutorial is a problem on which the pass criterion
used above stops working. The models that exercise these routes at size, and on harder
cases, are in `CapacityEquilibriaBenchmarks.jl`.

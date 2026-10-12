# CapacityEquilibria.jl — implementation brief

*What this package is, and what it promises. Where a docstring and this file disagree about
a contract, this file is the claim and the docstring describes the current implementation.*

## What it is

The engine underneath capacity-expansion equilibrium models: the complementarity plumbing,
the harness that solves one model with two independent solvers, and the residual
recomputation that decides whether either of them actually solved it.

It contains no models. Murphy and Smeers (2005) lives in `CapacityEquilibriaBenchmarks.jl`.
See `docs/BOUNDARY.md`.

## The contracts

**One model, two solvers.** `solve_complementarity(build, backend)` takes a *builder*, not a
model, and calls it once per backend. Two solvers can therefore never be given different
equations, which is the failure a comparison between them is supposed to detect rather than
contain. A JuMP model carries one optimizer and, under CCOpt, a set of bridges, so passing a
model instead of a builder would not merely be less tidy — the second solve would see a
model the first had already modified.

**A status is not evidence.** Every solve returns a point. Whether that point solves the
system is decided by `lcp_residual`, which recomputes primal feasibility, dual feasibility
and complementarity from the point alone and never consults the solver. This is
`DECISIONS.md` D-0002, and it is why the smoke test thresholds a residual rather than
asserting a termination status.

**PATH is ground truth.** CCOpt.jl is the object under test. When they disagree, the working
assumption is that CCOpt.jl is wrong, and overturning that assumption requires a finding,
not a preference.

**Data is an argument.** No parameter value in this package traces to a published source,
because none of them may (D-0003). Fixtures are synthetic and hand-checkable.

## Current state

The engine solves linear complementarity problems, through PATH and through CCOpt by three
routes, and judges every answer by a recomputed residual. That covers the open-loop models
in `CapacityEquilibriaBenchmarks.jl` and the second stage of its closed-loop model, which
are LCPs. The one problem built there that is not an LCP, a player's best response written
as an MPCC with a nonconvex objective, is built directly against CCOpt in that repository
and has not been generalised into the engine. There is no mixed or nonlinear
complementarity form here, no dispatch LP, no revenue-function interface, and no
equilibrium of anything.

The public API is `lcp_model`, `lcp_residual`, `solve_complementarity`,
`ComplementaritySolution`, `LCPVerticalModel` and `lcp_mpcc`. It is version `0.0.1` and
will change shape as the first nonlinear model arrives; nothing downstream should treat it
as stable yet.

The residual contract has one recorded limit. On a degenerate problem whose dual is an
unbounded ray, a solver can return a correct primal and a dual far out along the ray, and
the residual is then the product of the two: large, and not a measure of accuracy. A small
residual is evidence of a solution; a large one is evidence of a solution or of an
unbounded dual (`DECISIONS.md` D-0002, the appended note).

## Solver notes

**PATH** needs a licence for anything above 300 variables. Without `PATH_LICENSE_STRING`
set, PATHSolver.jl falls back to a size-limited demonstration licence and refuses larger
problems, which the test suite checks surfaces as a failure rather than a quiet
truncation. See `README.md`.

**CCOpt** reaches only its relaxation method through JuMP; its MathOptInterface layer builds
a `RelaxationSolver` unconditionally. The penalty method requires constructing the
`MPCCModels.MPCCModel` directly, which `lcp_mpcc` does. See
`docs/COMPLEMENTARITY_PAIRING.md` and `FINDINGS.md`.

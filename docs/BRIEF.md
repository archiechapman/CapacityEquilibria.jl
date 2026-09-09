# CapacityEquilibria.jl — implementation brief

*What this package is, and what it promises. Where a docstring and this file disagree about
a contract, this file is the claim and the docstring describes the current implementation.*

## What it is

The engine underneath a programme of capacity-expansion equilibrium models: the
complementarity plumbing, the harness that solves one model with two independent solvers,
and the residual recomputation that decides whether either of them actually solved it.

It contains no models of anything. Murphy and Smeers (2005) lives in
`CapacityEquilibriaBenchmarks.jl`; the adequacy mechanisms live in
`AdequacyMechanismSandpit.jl`. See `docs/BOUNDARY.md`.

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

Phase 0 of `CapacityEquilibriaBenchmarks.jl/docs/ms_ccopt_replication_plan.md`: the
environment is set up and a two-variable LCP with a known answer solves through both PATH
and CCOpt. That is all. There is no dispatch LP, no revenue-function interface, and no
equilibrium of anything yet.

The public API is `lcp_model`, `lcp_residual`, `solve_complementarity` and
`ComplementaritySolution`. It is version `0.0.1` and will change shape as the first real
model arrives; nothing downstream should treat it as stable yet.

## Solver notes

**PATH** needs a licence. Without `PATH_LICENSE_STRING` set, PATHSolver.jl falls back to a
size-limited demonstration licence, which is enough for the smoke test and will not be
enough for a real equilibrium. The free academic licence is the intended configuration and
registering it is Phase 0 work in the plan — see `README.md`.

**CCOpt** reaches only its relaxation method through JuMP; its MathOptInterface layer builds
a `RelaxationSolver` unconditionally. The penalty method requires constructing the
`MPCCModels.MPCCModel` directly. See `docs/COMPLEMENTARITY_PAIRING.md` and `FINDINGS.md`.

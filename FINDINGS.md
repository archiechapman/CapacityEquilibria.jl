# Findings — CapacityEquilibria.jl

*Whether the two solvers this programme depends on behave the way the plan assumed. Not
whether any model is right — no model exists here.*

*Last updated 2026-09-09. Produced against Julia 1.11.3, CCOpt v0.1.0, PATHSolver v1.7.9,
JuMP v1.31.2, MPCCModels v0.1.0, MathOptComplements v0.1.1, on Windows 11. Every number
below traces to a path named in its `evidence` field.*

Tiers are defined in `research-guardrails/QUALITY.md`. Statuses are `open`, `settled`,
`superseded`, `dead-end`. Ids are stable and never reused — cite `F-0001`, never the wording.

---

## F-0001 — PATH and CCOpt reach the same point on a two-variable LCP, judged by a residual neither of them computed.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `test/runtests.jl`, testsets "PATH", "CCOpt (relaxation)" and "the two backends agree"; 11/11 passing
- boundary: one 2×2 linear complementarity problem with a unique non-degenerate solution, on this machine and these package versions; assumes the hand-derived solution x = (2, 0) is correct, which is checkable by substitution and is asserted separately in the first testset; says nothing about problems large enough to hit PATH's demonstration-licence limit, about degenerate or multiple solutions, or about any equilibrium model
- supersedes: none

This is the Phase 0 gate from the replication plan: confirm a trivial complementarity
problem solves through both PATH and CCOpt before writing model code, so that a later
failure can be attributed to the model rather than the environment.

M = [2 1; 1 2], q = (−4, 1), solution x = (2, 0) with F = (0, 3). The problem was chosen so
that both branches of the complementarity are active — one variable positive with a zero
residual, one at its bound with a positive residual — because a problem with an interior
solution would leave the bound branch untested.

Both backends pass on `lcp_residual(...).worst < 1e-6`, recomputed from the returned point,
and neither testset asserts a termination status. That is the D-0002 discipline in the one
place it is currently exercisable.

## F-0002 — CCOpt.jl is registered and tagged, contradicting the premise of the plan's Phase 0.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: General registry after `Pkg.Registry.update()` — CCOpt uuid `6689419a-93c1-455a-8ac6-77991ec4f86b`, one version `0.1.0`, repo `https://github.com/madsuite-org/CCOpt.jl.git`
- boundary: the General registry as of this date; assumes the registry mirror is current, which `Pkg.Registry.update()` was run to ensure; a single tagged version is not the same as a stable API, so this narrows the pinning question without settling the compatibility one
- supersedes: none

The replication plan says CCOpt.jl "has no tagged releases at the time of writing" and
directs pinning it to a commit SHA in `Manifest.toml`. It has one tagged release, `0.1.0`,
and is in the General registry, so an ordinary compat bound does the job. This fires
`CapacityEquilibriaBenchmarks.jl` D-0003's own `revisit_if` on the day it was written.

The plan also names the upstream repository as `MadNLP/CCOpt.jl` in its Phase 5 outreach
step. It is `madsuite-org/CCOpt.jl`. `MPCCModels.jl` is likewise `madsuite-org`, though
CCOpt's README still points at `MadNLP/MPCCModels.jl`.

## F-0003 — The plan's sketch of CCOpt's API does not match the package.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `~/.julia/packages/CCOpt/QFgON/README.md` "Usage" and "Solution methods"; `names(CCOpt)` returns only `CCOpt` itself
- boundary: CCOpt v0.1.0; assumes the README describes the package rather than an aspiration, which the working smoke test supports for the relaxation path; the direct `MPCCModel` route in the README has not been exercised here, only the JuMP route
- supersedes: none

The plan specifies `CCOpt.MPCCModelVarVar(nlp, ind_x1, ind_x2)`. No such name exists. The
constructor is `MPCCModels.MPCCModel(nlp, ind_x1, ind_x2)`, from a separate package, and
solving is `CCOpt.solve_homotopy!(CCOpt.RelaxationSolver(mpcc))`.

CCOpt also exports nothing at all, so every name needs qualifying. And it has a JuMP path
the plan does not mention — `MathOptComplements` bridges plus `CCOpt.Optimizer` — which is
what `solve_complementarity` uses, and which matters well beyond Phase 0: it means the same
JuMP model can serve both solvers, rather than the MPCC being a hand-translated second
formulation that could drift from the first.

## F-0004 — CCOpt's penalty method is unreachable through JuMP.

- tier: validated
- status: open
- date: 2026-09-09
- evidence: `~/.julia/packages/CCOpt/QFgON/ext/CCOptMathOptInterface/CCOptMathOptInterface.jl`, `MOI.copy_to`, which assigns `dest.solver = CCOpt.RelaxationSolver(...)` with no branch on any option; unrecognised raw attributes are forwarded as keyword arguments rather than selecting a method
- boundary: CCOpt v0.1.0's MathOptInterface extension; assumes the absence of a branch means the absence of a documented way in, which reading the whole `copy_to` supports but a future version could change without notice; the direct `MPCCModel` route is unaffected and remains available
- supersedes: none

The oracle here is the installed source, read directly. What it is independent of is the
plan's API sketch and the README, both of which describe `PenaltySolver` as an equal
alternative without saying it is out of reach from the modelling layer.

This is a Phase 2 problem, not a Phase 0 one. The plan requires solving the open-loop case
with "both of CCOpt.jl's documented methods", and half of that cannot be done through the
JuMP model. Phase 2 therefore has to build the `MPCCModel` directly for the penalty run —
which reintroduces exactly the hand-translation risk the JuMP path removes, so the two
routes need checking against each other rather than being assumed equivalent.

---

## What this does not establish

- Nothing about correctness on any model of anything. There is no equilibrium in this
  package yet, and F-0001 is a solver check, not a modelling one.
- Nothing about problems at realistic scale. The smoke test is 2×2 and runs under PATH's
  demonstration licence; the academic licence is not yet registered, so the first real
  model is also the first test of that path.
- Nothing about CCOpt's accuracy relative to PATH beyond agreement to 1e-6 on one problem
  with one solution. Where the two disagree is the interesting case and has not occurred.
- Nothing about the penalty method's behaviour. F-0004 says it cannot be reached through
  JuMP, not that it works or does not work when reached directly.
- No claim that these package versions will resolve the same way tomorrow. The engine
  deliberately does not commit a `Manifest.toml` (D-0001 in the benchmarks repo covers the
  side that does).

## What remains

1. Register the PATH academic licence and re-run F-0001 with it, confirming the
   demonstration-licence fallback is not what has been passing. A **configuration**
   problem, and it blocks any model large enough to matter.
2. Build the direct `MPCCModels.MPCCModel` route so the penalty method is reachable, and
   check it against the JuMP route on the F-0001 problem (F-0004). A **code** problem,
   scheduled for Phase 2, and the point at which the two formulations could first diverge.
3. Decide whether `lcp_residual` generalises to the mixed complementarity systems the real
   models need, or whether it is the LCP-only special case it currently looks like. A
   **code** problem, and the first thing Phase 1 will press on.

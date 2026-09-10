# Findings — CapacityEquilibria.jl

*Whether the two solvers this programme depends on behave the way the plan assumed. Not
whether any model is right — no model exists here.*

*Last updated 2026-09-10. Produced against Julia 1.11.3, CCOpt v0.1.0, MadNLP v0.10.1,
PATHSolver v1.7.9, JuMP v1.31.2, MPCCModels v0.1.0, MathOptComplements v0.1.1, on
Windows 11. Every number
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
- status: settled
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

Settled on 2026-09-10 by F-0006, which builds that route and checks it. The claim in the
heading is unchanged and still true of v0.1.0; what was open was what to do about it, and
the answer is that the hand-translation risk it names did not materialise.

## F-0006 — The direct `MPCCModel` route reaches both of CCOpt's methods, and its relaxation solve returns the same point as the JuMP route.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: `test/runtests.jl`, testsets "LCPVerticalModel is the LCP, callback by callback", "CCOpt (relaxation, direct route)", "CCOpt (penalty, direct route)" and "the four backends agree", 41/41 passing — on the F-0001 problem the direct relaxation route returns a recomputed residual of 3.8e-9 at distance 1.3e-9 from PATH's point, the JuMP route the identical point (max-norm difference exactly 0.0, asserted with `==`), and the penalty route 2.2e-8 at distance 7.2e-9, all under a 1e-6 tolerance set before either was run; `src/lcp_nlp.jl` and `src/mpcc.jl` are the route
- boundary: CCOpt v0.1.0 over MadNLP v0.10.1, both methods at their default options apart from silence; one 2×2 LCP here, with the 14- and 18-variable Murphy–Smeers cases carried by the benchmarks repository's own ledger; the agreement of the two relaxation routes is exact and structural, which makes it brittle in a useful way: it is established only on problems whose map is affine and whose variables are all nonnegative, which is the only lifting the bridges are asked to do, and any change to the bridges' variable ordering would break it even where the solutions still agreed — free variables or a nonlinear map would exercise bridges these do not, and the agreement would have to be re-established rather than assumed; PATH returns this problem exactly, at residual 0.0, so the comparison of accuracies is not meaningful here and is made on the larger cases downstream instead; what matters is that neither CCOpt method sets the tolerance, which was fixed in advance; the failure mode is an index slip in the hand-written NLP that a single test point does not expose, which the point's all-distinct coordinates and the solver agreement argue against without excluding
- supersedes: none — settles F-0004

The route: `LCPVerticalModel(M, q)` is the LCP as a feasibility NLP in `z = (x, w)` with
`w − Mx = q` and `x, w ≥ 0`, whose every callback is a transcription of those two lines;
`lcp_mpcc` declares `z[i] ⟂ z[n + i]` on top of it by index and hands the `MPCCModel` to
`CCOpt.RelaxationSolver` or `CCOpt.PenaltySolver`. No JuMP, no bridges, no automatic
differentiation (D-0004).

Two things the agreement establishes. First, the bridges construct exactly the lifting
`lcp_mpcc` writes by hand. The two routes do not merely converge to the same answer: they
return bitwise identical vectors, on this problem and on all four Murphy–Smeers cases
downstream. That is a structural fact rather than a numerical one, and it is worth stating
in those terms — it says the MathOptComplements bridge stack, given an affine `[F; x]`
pairing over nonnegative variables, produces the same NLP in the same variable order that
this package builds directly, and that MadNLP is deterministic over it. It does not say
two independent numerical paths agreed, and an earlier draft of this entry which claimed
agreement "to twelve digits" invited exactly that misreading. Second, the pairing on the
direct route — two index vectors, which is the one place the two routes can differ by
construction (`docs/COMPLEMENTARITY_PAIRING.md`) — is right, and is checked directly by
the callback-level testset rather than only inferred from the solves. F-0008 mis-pairs it
on purpose and finds that the callback assertion and the relaxation route both go red. It
also finds that the *penalty* route does not, so the sentence that stood here — that a
swapped pair would have sent both direct solves elsewhere — was too strong, and the pairing
rests on the explicit assertion rather than on the solvers noticing.

What this does not do is compare the *methods*. Relaxation and penalty agreeing here is
two solvers reaching one easy solution, not evidence that they behave alike where it
matters, which is a degenerate or multiple-equilibrium problem neither has been given.

## F-0007 — CCOpt v0.1.0 throws on `MOI.RawStatusString`, so a JuMP user cannot read the solver's own wording of its status.

- tier: validated
- status: open
- date: 2026-09-10
- evidence: `~/.julia/packages/CCOpt/QFgON/ext/CCOptMathOptInterface/CCOptMathOptInterface.jl`, `MOI.get(::Optimizer, ::MOI.RawStatusString)`, which reads `optimizer.solver.opt`, while the `RelaxationSolver` it is handed declares the field `opts`; reproduced by calling `JuMP.raw_status` after any `:ccopt` solve, which raises `type RelaxationSolver has no field opt`; the same line stands on the `master` branch as read on 2026-09-10
- boundary: v0.1.0 and `master` at that date, on the relaxation solver the MathOptInterface extension always builds — a `MadNLPSolver`, which the extension falls back to when a model has no complementarity constraints, does have `.opt` and is unaffected; `MOI.TerminationStatus` is untouched, so nothing this programme decides on depends on the broken call; the failure mode is a later version renaming the field so that the guard in `src/solve.jl` catches a different error while reporting the same thing, which is why the guard records the error text rather than a blank
- supersedes: none

Cosmetic in this repository, because a solver's own account of its success is never the
pass criterion (D-0002) and `_raw_status` catches the exception and records the error text
in place of the wording. It is worth reporting upstream alongside the benchmarks
repository's test case: it is a one-word fix, and any JuMP user who calls `raw_status`
after a CCOpt solve hits it.

## F-0005 — The courtesy PATH licence lifts the demonstration size limit, and its absence fails loudly rather than quietly.

- tier: validated
- status: settled
- date: 2026-09-09
- evidence: `test/runtests.jl`, testset "PATH licence lifts the demonstration size limit"; a 400-variable LCP solves to `worst = 0.0` with `PATH_LICENSE_STRING` set and returns `OTHER_ERROR` with a `NaN` residual without it, both branches run before the test was written
- boundary: PATHSolver v1.7.9 on this machine, with the courtesy licence string published at `pages.cs.wisc.edu/~ferris/path/julia/LICENSE`; assumes 400 variables is above the demonstration limit and below any other, which the two-branch check establishes for this problem shape; the licence is dated to expire 31 December 2035, and says nothing about nonzero counts, which is the other demonstration limit and is untested
- supersedes: none

The concern this settles is not whether a licence exists but whether its absence is
detectable. It is: PATH does not silently truncate or degrade, it refuses, and the refusal
propagates as a `NaN` residual that fails a threshold rather than passing one. So the
failure mode that would have been dangerous — a large model quietly solved as something
smaller — is not the failure mode that occurs.

The test skips when `PATH_LICENSE_STRING` is unset rather than failing, since an unlicensed
checkout is a legitimate state, and logs why. What it does not do is pass.

The string is a courtesy licence for general use, not an individually issued academic one.
It is not committed anywhere in these repositories and should not be.


## F-0008 — The direct route's tests fail when the model is broken, and the callback-level test is what catches it — but the penalty backend alone would not have.

- tier: validated
- status: settled
- date: 2026-09-10
- evidence: three single-token mutations applied to a snapshot of the engine source, the suite run against each, and the file restored byte for byte afterwards (driver kept out of the repository; the mutations are stated below so they can be reapplied by hand) — (i) the pairing in `lcp_mpcc` rotated so that `x[i]` is paired with `w[i+1]`: 5 failures, one of them in "LCPVerticalModel is the LCP, callback by callback"; (ii) the Jacobian sparsity in `_lcp_jac_structure!` transposed by swapping `rows[k]` and `cols[k]`: 3 failures and 3 errors, one error in the callback test; (iii) the constraint sign flipped, `[-M I]` written as `[M I]`: 12 failures, four of them in the callback test
- boundary: three mutations on one 2×2 problem, so this shows each check is live, not that the set of mutations is complete; each mutation is a single token, and a subtler one — a Jacobian correct except in one entry, say — has not been tried; the JuMP-route testsets are correctly insensitive to the two `lcp_nlp.jl` mutations because that route does not use the file, which is a consistency check on the controls themselves rather than a result; the controls were run against CCOpt v0.1.0 over MadNLP v0.10.1 and would need re-running after a version move, since what a solver does with a broken model is a property of the solver
- supersedes: none

Run because the Phase 2 self-review found that none of the new checks had been seen to
fail, which by this repository's own standard is not yet knowing they are checks. All three
mutations were caught. Two details are worth more than that headline.

**The callback test earns its place.** "LCPVerticalModel is the LCP, callback by callback"
went red on all three, and it is the only testset that localises the fault: it says the
Jacobian is wrong, rather than saying a solver did not reach the answer. Its single test
point with all-distinct coordinates was enough for every mutation tried, which is the
argument F-0006's boundary makes and which had not until now been tested.

**The penalty backend did not catch the mis-paired complementarity.** Under mutation (i)
the testset "CCOpt (penalty, direct route)" passed both of its assertions, while the
relaxation route's failed and the callback test's pairing assertion failed. So on this
problem the penalty method returned a point that satisfies the *unmutated* LCP even though
it was handed a mis-paired one. That is a fact about this problem and this solver rather
than a defect — the residual is recomputed against the real `M` and `q`, so nothing false
was asserted — but it means the penalty backend is not, on its own, a check on the pairing.
The pairing is checked by the callback test and by the relaxation route, and F-0006's
argument that "a swapped pair would have sent both direct solves to a different problem"
is too strong as written: it sent one of them there.

The mutations, for reanalysis:

| # | file | change |
|---|---|---|
| i | `src/mpcc.jl` | `collect(n + 1:2n)` becomes `vcat(collect(n + 2:2n), [n + 1])` |
| ii | `src/lcp_nlp.jl` | in `_lcp_jac_structure!`, `rows[k] = A.rowval[p]; cols[k] = col` becomes `rows[k] = col; cols[k] = A.rowval[p]` |
| iii | `src/lcp_nlp.jl` | `[-Matrix{T}(M) …]` becomes `[Matrix{T}(M) …]` |

The benchmarks repository's own controls, for the emitted upstream file and the regime
classification, are its `FINDINGS.md` F-0010 and `scripts/negative_controls.jl`.

---

## What this does not establish

- Nothing about correctness on any model of anything. There is no equilibrium in this
  package yet, and F-0001 is a solver check, not a modelling one.
- Nothing about problems at realistic scale. The largest problem solved here is a
  400-variable LCP built to test the licence (F-0005), not a model of anything; CCOpt has
  only ever been run on the 2×2.
- Nothing about CCOpt's accuracy relative to PATH beyond agreement to 1e-6 on one problem
  with one solution. Where the two disagree is the interesting case and has not occurred.
- Nothing about the penalty method's behaviour. F-0004 says it cannot be reached through
  JuMP, not that it works or does not work when reached directly.
- No claim that these package versions will resolve the same way tomorrow. The engine
  deliberately does not commit a `Manifest.toml` (D-0001 in the benchmarks repo covers the
  side that does).

## What remains

1. ~~Register the PATH licence.~~ Done — F-0005. The courtesy licence solves 400
   variables and its absence is detectable. An individually issued academic licence is
   still worth having before the closed-loop runs, since the courtesy string is shared and
   dated.
2. ~~Build the direct `MPCCModels.MPCCModel` route so the penalty method is reachable, and
   check it against the JuMP route on the F-0001 problem (F-0004).~~ Done — F-0006. The
   two formulations did not diverge, and the bridges turned out to change nothing.
3. Decide whether `lcp_residual` generalises to the mixed complementarity systems the real
   models need, or whether it is the LCP-only special case it currently looks like. A
   **code** problem, and the first thing Phase 1 will press on.
4. Report F-0007 upstream with the benchmarks repository's test case, and check whether a
   later CCOpt release has fixed it before the `CCOpt = "0.1"` bound is widened.
5. ~~Confirm the direct route's tests fail when the model is broken.~~ Done — F-0008.

# CapacityEquilibria.jl

The complementarity engine for a programme of capacity-expansion equilibrium models: the
`MOI.Complements` plumbing, a harness that solves one model with two independent solvers,
and the residual recomputation that decides whether either of them actually solved it.

No models live here. Murphy and Smeers (2005) is in `CapacityEquilibriaBenchmarks.jl`; the
adequacy mechanisms are in `AdequacyMechanismSandpit.jl`. See `docs/BOUNDARY.md`.

**Status: the linear engine is complete; the nonlinear one is not started.** A two-variable
LCP with a hand-checkable answer solves through PATH and through CCOpt by three routes —
its relaxation method via JuMP, and its relaxation and penalty methods via an `MPCCModel`
built directly — and all four land on the same point, the two relaxation routes bitwise.
The tests that guard the direct route have been seen to fail when the route is broken
(`FINDINGS.md` F-0008). One limit on the pass criterion has been found and recorded rather
than absorbed: on a degenerate problem whose dual is an unbounded ray, the recomputed
residual measures where along the ray a solver stopped, not whether it solved anything
(the note appended to `DECISIONS.md` D-0002). The models that exercise these routes at
size, and on harder problems, live in `CapacityEquilibriaBenchmarks.jl`.

## Getting set up

```
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.test()'
```

Forty-one tests should pass in about two minutes after precompilation (forty, with one
skipped, if no PATH licence is configured — see below).

### PATH licence

PATHSolver.jl falls back to a demonstration licence — 300 variables, 2000 nonzeros — when
none is configured. That is enough for the test suite here and will not be enough for a real
equilibrium.

A courtesy licence covering unlimited problem size is published by the PATH authors at
<https://pages.cs.wisc.edu/~ferris/path/julia/LICENSE>, currently dated to 31 December 2035.
Set it before it starts mattering, rather than when a size limit is first hit:

```
export PATH_LICENSE_STRING="<string from the URL above>"     # bash
$env:PATH_LICENSE_STRING = "<string from the URL above>"     # PowerShell, this session
setx PATH_LICENSE_STRING "<string from the URL above>"       # PowerShell, permanently
```

The test suite checks this rather than trusting it: with the variable set, a 400-variable
LCP solves; without it, PATH returns `OTHER_ERROR` and a `NaN` residual, so an unlicensed
run fails a threshold rather than passing one (`FINDINGS.md` F-0005). The testset skips,
with a note, when the variable is absent.

That string is a shared courtesy licence, not an individually issued academic one — worth
requesting your own from <https://pages.cs.wisc.edu/~ferris/path.html> before the closed-loop
runs. **No licence string is recorded anywhere in this repository, and none should be.**

## Usage

```julia
using CapacityEquilibria

M, q = [2.0 1.0; 1.0 2.0], [-4.0, 1.0]
build() = lcp_model(M, q)                       # 0 ≤ x ⟂ Mx + q ≥ 0

path  = solve_complementarity(build, :path)
ccopt = solve_complementarity(build, :ccopt)    # CCOpt's relaxation method, through JuMP

lcp_residual(M, q, path.x).worst                # 0.0 — the pass criterion
path.x ≈ ccopt.x                                # true

# The direct route: the same LCP as an MPCCModel built without JuMP, which is the only way
# to reach CCOpt's penalty method. Takes (M, q) rather than a builder, and accepts :path
# and :ccopt too, building the JuMP model itself.
penalty = solve_complementarity(M, q, :ccopt_penalty)
direct  = solve_complementarity(M, q, :ccopt_relaxation)
```

`solve_complementarity(build, backend)` takes a *builder*, not a model, and calls it once
per backend. Two solvers therefore cannot be handed different equations, and neither solve
inherits bridges or an optimizer the other one attached.

The pass criterion is the residual, never the termination status. `lcp_residual` recomputes
primal feasibility, dual feasibility and complementarity from the returned point alone; a
solver reporting success on a mis-specified pairing is telling the truth about the problem it
was given, not about the one you meant. This is the subject of `docs/COMPLEMENTARITY_PAIRING.md`,
which is worth reading before touching the pairing.

## Dependencies worth knowing about

| Package | Role |
|---|---|
| `PATHSolver.jl` | Ground truth. Commercial, free academic licence — deliberate, see `DECISIONS.md` D-0002. |
| `CCOpt.jl` | The object under test. v0.1.0, `madsuite-org/CCOpt.jl`. |
| `MathOptComplements.jl` | Bridges an affine `[F; x]` pairing into the variable-pairing form CCOpt's optimizer requires. |
| `MPCCModels.jl`, `NLPModels.jl`, `MadNLP.jl` | The direct route. `LCPVerticalModel` is an `NLPModels.AbstractNLPModel`, `lcp_mpcc` wraps it as an `MPCCModels.MPCCModel`, and both of CCOpt's solvers run over MadNLP. |
| `NLPModelsJuMP.jl` | Pulled in by CCOpt's JuMP path, and required for the extension that defines `CCOpt.Optimizer` to load at all. |

CCOpt reaches only its relaxation method through JuMP (`FINDINGS.md` F-0004). The direct
`MPCCModel` route in `src/mpcc.jl` reaches both of its methods, and on every problem tried
so far the relaxation method returns the same point by either route (F-0006).

## Documentation

A documentation site builds from `docs/`:

```
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl          # writes docs/build/index.html
```

It holds two tutorials and the API reference. *One LCP, four routes* solves the Phase 0
problem through every backend and breaks the pairing on purpose to show what a wrong one
does: it converges, reports success, and is answered only by the residual. *When the
residual stops measuring accuracy* is a two-variable problem with an unbounded dual ray,
on which the pass criterion itself fails, which is the D-0002 limit in its smallest form.

Every code block in the tutorials runs during the build, and each claim the prose makes is
an `@assert` beside it, so a claim that stops holding fails the build. The build takes
about a minute and a half once packages are compiled. The design notes and the two ledgers
are copied into the site from their canonical files at build time rather than duplicated.
`make.jl` deploys only from CI, which does not exist yet and will not until this
repository is public (D-0001).

## Documents

- `AGENTS.md` — the agent guide, and the hard rules
- `docs/src/` — the documentation site's own pages: the tutorials and the API reference
- `docs/BRIEF.md` — what this package promises
- `docs/BOUNDARY.md` — what belongs here versus downstream
- `docs/COMPLEMENTARITY_PAIRING.md` — the one dangerous area
- `FINDINGS.md`, `DECISIONS.md` — the claim ledger and the decision log

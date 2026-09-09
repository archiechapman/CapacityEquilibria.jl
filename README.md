# CapacityEquilibria.jl

The complementarity engine for a programme of capacity-expansion equilibrium models: the
`MOI.Complements` plumbing, a harness that solves one model with two independent solvers,
and the residual recomputation that decides whether either of them actually solved it.

No models live here. Murphy and Smeers (2005) is in `CapacityEquilibriaBenchmarks.jl`; the
adequacy mechanisms are in `AdequacyMechanismSandpit.jl`. See `docs/BOUNDARY.md`.

**Status: Phase 0.** A two-variable LCP with a hand-checkable answer solves through both
PATH and CCOpt and the two agree. That is all that is claimed — see `FINDINGS.md`.

## Getting set up

```
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.test()'
```

Eleven tests should pass in about a minute after precompilation.

### PATH licence

PATHSolver.jl falls back to a size-limited demonstration licence when none is configured.
That is enough for the test suite and will not be enough for a real equilibrium, so register
the free academic licence before it starts mattering rather than when a size limit is first
hit:

```
export PATH_LICENSE_STRING="..."      # bash
$env:PATH_LICENSE_STRING = "..."      # PowerShell
```

The licence is issued at <https://pages.cs.wisc.edu/~ferris/path.html>. Nothing in this
repository records one, and nothing should.

## Usage

```julia
using CapacityEquilibria

M, q = [2.0 1.0; 1.0 2.0], [-4.0, 1.0]
build() = lcp_model(M, q)                       # 0 ≤ x ⟂ Mx + q ≥ 0

path  = solve_complementarity(build, :path)
ccopt = solve_complementarity(build, :ccopt)

lcp_residual(M, q, path.x).worst                # 0.0 — the pass criterion
path.x ≈ ccopt.x                                # true
```

`solve_complementarity` takes a *builder*, not a model, and calls it once per backend. Two
solvers therefore cannot be handed different equations, and neither solve inherits bridges
or an optimizer the other one attached.

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
| `MPCCModels.jl`, `NLPModelsJuMP.jl` | Pulled in by CCOpt's JuMP path; needed directly once the penalty method is reached (`FINDINGS.md` F-0004). |

CCOpt reaches only its relaxation method through JuMP. The penalty method needs the direct
`MPCCModel` route and is not built yet.

## Documents

- `AGENTS.md` — the agent guide, and the hard rules
- `docs/BRIEF.md` — what this package promises
- `docs/BOUNDARY.md` — what belongs here versus downstream
- `docs/COMPLEMENTARITY_PAIRING.md` — the one dangerous area
- `FINDINGS.md`, `DECISIONS.md` — the claim ledger and the decision log

# CapacityEquilibria.jl

A complementarity engine for capacity-expansion equilibrium models. It builds a problem
once, hands the same problem to two independent solvers, PATH and CCOpt.jl, and decides
whether either of them solved it by recomputing the residual from the returned point.

There are no models here. The Murphy and Smeers (2005) equilibria that exercise the engine
are in [CapacityEquilibriaBenchmarks.jl](https://github.com/archiechapman/CapacityEquilibriaBenchmarks.jl).

**Status.** The engine solves linear complementarity problems through PATH and through
CCOpt by three routes: CCOpt's relaxation method via JuMP, and its relaxation and penalty
methods via an `MPCCModel` built directly. On every problem tried, all four land on the
same point, and the two relaxation routes agree bitwise. Mixed and nonlinear
complementarity forms are not yet supported.

## Installation

The package is not registered. Clone it, then:

```
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.test()'
```

Forty-one tests pass in about two minutes after precompilation (forty and one skipped
without a PATH licence; see below).

### PATH licence

Without a licence PATHSolver.jl falls back to a demonstration limit of 300 variables and
2000 nonzeros, enough for the tests and not for a real equilibrium. The PATH authors
publish a courtesy licence at <https://pages.cs.wisc.edu/~ferris/path/julia/LICENSE>. Set
it as an environment variable:

```
export PATH_LICENSE_STRING="<string from the URL above>"     # bash
setx PATH_LICENSE_STRING "<string from the URL above>"       # Windows, permanently
```

The test suite checks that the licence has taken: with it, a 400-variable LCP solves;
without it, PATH refuses and the residual is `NaN`, which fails a threshold rather than
passing one (`FINDINGS.md` F-0005). No licence string is stored in this repository.

## Usage

```julia
using CapacityEquilibria

M, q = [2.0 1.0; 1.0 2.0], [-4.0, 1.0]
build() = lcp_model(M, q)                       # 0 ≤ x ⟂ Mx + q ≥ 0

path  = solve_complementarity(build, :path)
ccopt = solve_complementarity(build, :ccopt)    # CCOpt's relaxation method, through JuMP

lcp_residual(M, q, path.x).worst                # 0.0, the pass criterion
path.x ≈ ccopt.x                                # true

# The direct route: the same LCP as an MPCCModel built without JuMP, the only way to reach
# CCOpt's penalty method.
penalty = solve_complementarity(M, q, :ccopt_penalty)
direct  = solve_complementarity(M, q, :ccopt_relaxation)
```

`solve_complementarity(build, backend)` takes a builder, not a model, and calls it once per
backend, so two solvers cannot be handed different equations and neither inherits bridges
or an optimizer the other attached.

The pass criterion is the residual, never the termination status. `lcp_residual`
recomputes primal feasibility, dual feasibility and complementarity from the returned
point alone. A solver reporting success on a mis-specified pairing is telling the truth
about the problem it was given, not the one you meant; `docs/COMPLEMENTARITY_PAIRING.md`
explains why the pairing is the one place a mistake is silent.

The criterion has one recorded limit. On a degenerate problem whose dual is an unbounded
ray, the residual measures where along the ray a solver stopped, not whether it solved
anything (`DECISIONS.md` D-0002).

## Dependencies

| Package | Role |
|---|---|
| `PATHSolver.jl` | Ground truth. Commercial, with a free academic licence; deliberate (D-0002). |
| `CCOpt.jl` | The solver under test, `madsuite-org/CCOpt.jl`. |
| `MathOptComplements.jl` | Bridges an affine `[F; x]` pairing into the variable-pairing form CCOpt's optimizer requires. |
| `MPCCModels.jl`, `NLPModels.jl`, `MadNLP.jl` | The direct route: `LCPVerticalModel` is an `AbstractNLPModel`, `lcp_mpcc` wraps it as an `MPCCModel`, and both CCOpt methods run over MadNLP. |
| `NLPModelsJuMP.jl` | Required for the extension that defines `CCOpt.Optimizer` to load. |

CCOpt reaches only its relaxation method through JuMP (F-0004). The direct route reaches
both, and its relaxation solve returns the same point as the JuMP route (F-0006).

## Documentation

```
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl          # writes docs/build/index.html
```

Two tutorials and the API reference. *One LCP, four routes* solves a two-variable problem
through every backend, then breaks the pairing on purpose: the solver converges, reports
success, and only the residual catches it. *When the residual stops measuring accuracy*
is the D-0002 limit in its smallest form. Every claim in the tutorials is an `@assert`
beside the code, so a claim that stops holding fails the build. The design notes and
ledgers are copied in from their canonical files at build time.

## Repository guide

- `docs/BRIEF.md`: what the package promises
- `docs/BOUNDARY.md`: what belongs here and what belongs in a model repository
- `docs/COMPLEMENTARITY_PAIRING.md`: the one dangerous area
- `FINDINGS.md`, `DECISIONS.md`: the claim ledger and the decision log
- `upstream/ccopt_raw_status_string/`: a fix for CCOpt.jl's `MOI.RawStatusString` (F-0007)
  and its test, checked by `scripts/check_raw_status_fix.jl` (F-0009)
- `AGENTS.md`: conventions for automated contributors

## Licence

BSD 3-Clause. See `LICENSE`.

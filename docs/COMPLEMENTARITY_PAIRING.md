# The complementarity pairing

*`AGENTS.md` names this as the one dangerous area. This file is the long version of the two
rules it states.*

## Why this is the dangerous area

A complementarity system says that for each `i`, either `xᵢ = 0` or `Fᵢ(x) = 0`. Which `F`
goes with which `x` is the entire content of the model. Get it wrong and nothing errors:
the solver is handed a perfectly well-posed problem, converges on it cleanly, reports
success, and returns the answer to a system nobody meant to write. In a capacity-expansion
equilibrium the output of that is a set of capacities and prices that look like capacities
and prices.

Compare this with the failure modes elsewhere in the codebase, which announce themselves —
a dimension mismatch throws, a missing parameter throws, an infeasible LP says so. The
pairing is the one place where being wrong is quiet.

## How the pairing is expressed

One `MOI.Complements` constraint over a single stacked vector:

```julia
@constraint(model, [F; x] in MOI.Complements(2n))
```

`F[i]` is paired with `x[i]` because they sit exactly `n` apart in one vector. This is the
whole reason `lcp_model` builds the constraint this way rather than looping over `n`
separate scalar constraints: there is one ordering, established once, and no second list
that could drift out of step with the first.

The convention — first half is `F`, second half is the variables, and `dimension` is the
total `2n` rather than the number of pairs — is worth confirming rather than remembering.
CCOpt's own MathOptInterface layer reads it as `fun.variables[cc]` against
`fun.variables[cc + div(set.dimension, 2)]`, which is the same convention, and the smoke
test in `test/runtests.jl` would fail on a point-by-point comparison if either end of that
were wrong.

## Never trust a solve that converged

`solve_complementarity` returns the point and the status; `lcp_residual` decides whether the
point is a solution, from the point alone. Nothing in the pass criterion consults the
solver.

This is `DECISIONS.md` D-0002 and `QUALITY.md`'s `validated` tier applied to the place it
actually bites. Concretely, the smoke test asserts `lcp_residual(...).worst < TOL` and does
*not* assert `status == OPTIMAL`. A solver reporting `LOCALLY_SOLVED` on a wrong pairing is
telling the truth about the problem it was given.

## Always derive the index vectors from the same object

CCOpt does not consume `MOI.Complements` directly. Its optimizer filters the complementarity
constraints out of the model, builds an `NLPModel` from what remains, and reconstructs the
pairing as two index vectors `ind_x1`, `ind_x2` handed to `MPCCModels.MPCCModel`. The
`MathOptComplements` bridges sit in front of that, rewriting an affine `[F; x]` pairing into
one over variables, which is the form the optimizer requires.

Everything in that chain derives from the single constraint built in `lcp_model`. The
failure to avoid is re-deriving the index vectors by listing the model's variables in what
looks like the same order — which works, until a bridge introduces an auxiliary variable, or
a term is added to `F`, and the two orderings quietly stop matching. If you find yourself
writing `1:n` and `n+1:2n` against a variable list you did not build in the same expression,
stop.

## Known limitation, so it is not rediscovered

CCOpt's MathOptInterface layer constructs a `CCOpt.RelaxationSolver` unconditionally. There
is no raw optimizer attribute that selects `CCOpt.PenaltySolver`, so the penalty method is
not reachable through JuMP at all. Solving with both of CCOpt's methods means building the
`MPCCModel` directly, which `lcp_mpcc` does. See `FINDINGS.md` F-0004 and F-0006.

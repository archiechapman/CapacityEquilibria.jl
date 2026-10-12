# CapacityEquilibria.jl

A complementarity engine for capacity-expansion equilibrium models. It does three things:
it builds a complementarity problem once and hands the same problem to two independent
solvers, it recomputes from each returned point whether that point actually solves the
problem, and it keeps the pairing of variables with conditions, the one place where a
mistake converges cleanly to a wrong answer, in a single expression.

There are no models here. Murphy and Smeers' capacity-expansion equilibria live in
`CapacityEquilibriaBenchmarks.jl`, which depends on this package; this package depends on
nothing downstream.

## The contracts

**One model, two solvers.** [`solve_complementarity`](@ref) takes a *builder*, a
zero-argument function returning `(model, x)`, and calls it once per solver. Two solvers
therefore cannot be handed different equations, and neither solve sees bridges or an
optimizer the other attached.

**A status is not evidence.** [`lcp_residual`](@ref) recomputes primal feasibility, dual
feasibility and complementarity from the returned point alone. It never asks the solver how
the solve went. The pass criterion everywhere in this programme is that residual, never a
termination status.

**PATH is ground truth, and CCOpt.jl is the object under test.** PATH is mature commercial
software under a free academic licence; CCOpt.jl is a young open-source MPCC solver. When
they disagree the working assumption is that CCOpt.jl is wrong, and overturning that takes
a recorded finding rather than a preference.

**Data is an argument.** No parameter in this package traces to a published source. The
fixtures are synthetic and small enough to check by hand.

## The four backends

| Backend | Solver | Route |
|---|---|---|
| `:path` | PATH | JuMP, one `MOI.Complements` constraint |
| `:ccopt` | CCOpt, relaxation method | JuMP, through the MathOptComplements bridges |
| `:ccopt_relaxation` | CCOpt, relaxation method | an `MPCCModel` built directly, no JuMP |
| `:ccopt_penalty` | CCOpt, ℓ₁ penalty method | an `MPCCModel` built directly, no JuMP |

CCOpt's JuMP layer builds its relaxation solver unconditionally, so the penalty method can
only be reached by the direct route. On every problem tried so far the two relaxation
routes return bitwise identical points, which says the bridges build exactly the lifted
model this package writes by hand.

## Installing

The package is not yet registered. Clone it and instantiate:

```
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.test()'
```

PATH falls back to a demonstration licence of 300 variables and 2000 nonzeros when none is
configured. The PATH authors publish a courtesy licence at
<https://pages.cs.wisc.edu/~ferris/path/julia/LICENSE>; set it as the environment variable
`PATH_LICENSE_STRING`. The test suite checks that the licence has taken rather than
assuming it: a 400-variable problem solves with it and fails loudly without it.

## Where to start

- [One LCP, four routes](@ref) solves the smallest problem with a known answer through every
  backend, and shows what a wrong pairing does.
- [When the residual stops measuring accuracy](@ref) is a two-variable problem on which the
  pass criterion itself fails, and says what that means for everything built on it.
- The design notes explain what belongs in this package, and why the pairing is the one
  dangerous area.
- The ledgers record every claim made about the solvers, with its evidence and its limits.

The models that exercise all of this at size, with a tutorial series of their own, are in
`CapacityEquilibriaBenchmarks.jl`.

## Acknowledgements

The ground-truth solves depend on PATH. Thanks to Steven Dirkse, Michael Ferris and Todd
Munson for the solver and its courtesy licence, and to the PATHSolver.jl contributors for
the Julia interface. Thanks also to François Pacaud, Anton Pozharskiy and Armin Nurkanović
for CCOpt.jl, the solver this package exists to test, and to the authors of MPCCModels.jl
and MathOptComplements.jl.

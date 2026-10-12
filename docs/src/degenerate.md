# When the residual stops measuring accuracy

The previous tutorial judged every solver by one number: the residual recomputed from its
point by [`lcp_residual`](@ref). That criterion has been the pass condition for this whole
programme since its first test (`DECISIONS.md` D-0002). This page is a two-variable
problem on which it stops meaning what it appears to mean.

The problem is not contrived. It is a one-segment slice of a situation that arose on its
own in `CapacityEquilibriaBenchmarks.jl`, where a generator holding no capacity makes the
output stage of a capacity game degenerate (that repository's F-0015). The engine holds no
model data, so here it is written down directly.

## A firm with no capacity

One firm, capacity ``x = 0``, chooses output ``y`` against inverse demand ``a - y`` with its
own effect on price counted twice, as a Cournot player would. Its capacity constraint
``y \le x`` has shadow price ``\lambda``. The conditions are

```math
\begin{aligned}
0 \le y       &\;\perp\; -a + 2y + \lambda \ge 0, \\
0 \le \lambda &\;\perp\; x - y \ge 0 .
\end{aligned}
```

With ``x = 0`` the second line forces ``y = 0``, and then the first line holds for *any*
``\lambda \ge a``. The solution set is not a point. It is a ray.

```@example ray
using CapacityEquilibria

a = 3.0
M = [2.0 1.0; -1.0 0.0]     # rows: the output condition, then the capacity condition
q = [-a, 0.0]               # x = 0 sits in the second entry

for λ in (a, 10.0, 1e3, 1e5)
    @assert lcp_residual(M, q, [0.0, λ]).worst == 0.0
end
[lcp_residual(M, q, [0.0, λ]).worst for λ in (a, 10.0, 1e3, 1e5)]
```

Every point on the ray has residual exactly zero. Nothing in the problem prefers one of
them, and the shadow price of capacity for a firm holding none is genuinely undetermined.

## What the solvers return

```@example ray
sols = [solve_complementarity(M, q, b)
        for b in (:path, :ccopt, :ccopt_relaxation, :ccopt_penalty)]

for s in sols
    r = lcp_residual(M, q, s.x)
    println(rpad(s.backend, 18), "y = ", rpad(round(s.x[1]; sigdigits = 3), 12),
            "λ = ", rpad(round(s.x[2]; sigdigits = 6), 12), "residual ", r.worst)
end
```

Four solvers, all reporting success, all with the right primal: output is zero to within
1e-8 everywhere. PATH returns the vertex of the ray, ``\lambda = a``. Both CCOpt methods walk
a long way out along it.

```@example ray
path, penalty = sols[1], sols[4]
@assert all(string(s.status) == "LOCALLY_SOLVED" for s in sols)   # every status is success
@assert all(abs(s.x[1]) < 1e-7 for s in sols)            # the primal is right everywhere
@assert isapprox(path.x[2], a; atol = 1e-6)               # PATH stops at the vertex
@assert all(s.x[2] > 1e3 for s in sols[2:4])              # CCOpt does not
@assert lcp_residual(M, q, penalty.x).worst > 1e-5        # and one residual looks bad
nothing # hide
```

## Why the penalty residual is large

The penalty method's residual is orders of magnitude worse than the relaxation method's.
It is not an error of that size in anything with meaning. At a point ``(y, \lambda)`` with a tiny
positive ``y``, the capacity condition is ``-y``, so the complementarity term is
``\lambda y``: a large dual multiplied by a tiny primal error.

```@example ray
y, λ = penalty.x
@assert isapprox(lcp_residual(M, q, penalty.x).worst, λ * y; rtol = 1e-3)
(residual = lcp_residual(M, q, penalty.x).worst, λ_times_y = λ * y)
```

Snap the output exactly onto its bound and the residual collapses, whatever ``\lambda`` is:

```@example ray
@assert lcp_residual(M, q, [0.0, λ]).worst == 0.0
lcp_residual(M, q, [0.0, λ]).worst
```

The same arithmetic applied to a point near the vertex gives a tiny residual for the same
primal error:

```@example ray
lcp_residual(M, q, [y, a]).worst
```

So on this problem the residual reports how far along the ray a solver stopped, not whether
it solved anything. The primal error is the same size at both points; the residual differs
by the ratio of the two duals.

## What this means for the pass criterion

A small residual is still evidence of a solution. A large one is evidence of a solution
*or* of an unbounded dual, and the number alone cannot tell the two apart. Telling them
apart needs the problem's structure: which pairs are biactive, whether the basis is
singular, whether the primal agrees with an independent solver.

D-0002 is not changed by this. The alternative it rejects, believing a termination
status, is worse in every case including this one: here all four statuses are success, and
one of them is attached to a residual of 1e-3. What changes is what the criterion supports.
Downstream work that thresholds a residual on a possibly degenerate problem should say
which of the two readings it is assuming. The note appended to D-0002 in the decision log
records this, and item 5 of "What remains" in the findings ledger is the open question of
what should replace the residual on such problems.

In `CapacityEquilibriaBenchmarks.jl` the same thing happens at the four capacity vectors
where a player invests nothing. Those are exactly the points where the capacity game's
first-order conditions have roots that are not equilibria, and the two facts have the same
cause. That repository's tutorial series walks through it.

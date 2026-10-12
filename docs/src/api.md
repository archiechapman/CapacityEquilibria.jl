# API reference

The public API is small and at version `0.0.1`. It will change shape as the first
nonlinear model arrives, so nothing downstream should treat it as stable yet.

```@docs
CapacityEquilibria
```

## Building a problem

```@docs
lcp_model
LCPVerticalModel
lcp_mpcc
```

## Solving it

```@docs
solve_complementarity
ComplementaritySolution
```

## Judging the answer

```@docs
lcp_residual
```

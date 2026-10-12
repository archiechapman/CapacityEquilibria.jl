# What belongs here, and what belongs downstream

*The split between the engine and the repositories that use it is `DECISIONS.md` D-0001.
This file is the working version: what to do when you are holding a piece of code and are
not sure where it goes.*

## The split

| Repository | Holds |
|---|---|
| `CapacityEquilibria.jl` | The engine: complementarity plumbing, the two-solver harness, residual recomputation, and later the dispatch LP and the revenue-function interface. |
| `CapacityEquilibriaBenchmarks.jl` | Published models with known answers, starting with Murphy and Smeers (2005). Owns `data/` and its provenance. |
| Application repositories | Models built on the engine for a particular study. |

Dependencies run **downstream only**: model repositories may depend on the engine, and the
engine may depend on none of them. This is a hard rule in `AGENTS.md` because breaking it
is not something the compiler reports until registration fails.

## The test to apply

Ask what would have to change for the code to be wrong.

- Wrong because a **solver** behaves differently than assumed: engine.
- Wrong because a **number was transcribed** from a paper incorrectly: benchmarks.
- Wrong because a **model of a particular market or policy** is mis-specified: the
  application repository.

Code that is wrong for two of those reasons at once is usually two pieces of code that have
not been separated yet.

## Cases that come up

**A helper that builds a model from data.** Engine, if the data is an argument. Benchmarks,
if the helper knows the shape of Murphy and Smeers' load segments. The line is whether a
second paper with a different structure could use it unchanged.

**A tolerance.** Engine, if it is a property of the solver: what counts as a converged
complementarity residual. Benchmarks, if it is the tolerance at which a published number is
declared reproduced, because that is a claim about the replication, not about arithmetic.

**A fixture.** Engine fixtures are synthetic and hand-checkable, like the two-variable LCP
in `test/runtests.jl`. Once a fixture's numbers come from a paper it belongs downstream,
however small it is.

**Something several downstream repositories want.** It goes in the engine, but not on the
first request. Wait for a second real caller, or the interface gets designed around the
first and has to be rebuilt.

## What the engine may never contain

Paper-specific parameter values (D-0003), transcribed tables, unpublished results, or
anything whose provenance is a source it cannot name.

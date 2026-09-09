# What belongs here, and what belongs downstream

*The three-repository split is `DECISIONS.md` D-0001. This file is the working version of
it: what to do when you are holding a piece of code and are not sure where it goes.*

## The three repositories

| Repository | Holds | Visibility |
|---|---|---|
| `CapacityEquilibria.jl` | The engine. Complementarity plumbing, the dual-solver harness, residual recomputation, and — later — the dispatch LP and the revenue-function interface. | Private; opens when it has an engine (D-0001) |
| `CapacityEquilibriaBenchmarks.jl` | Published models with published answers. Murphy and Smeers (2005) first. Owns `data/` and its provenance. | Private; opens on its Phase 1 gate |
| `AdequacyMechanismSandpit.jl` | The adequacy-mechanism programme. Stochastic extension, ORDC, CIS, and the rest of the roadmap. | Private; opens per publication |

Dependencies run **downstream only**: benchmarks and sandpit may depend on the engine, the
engine may depend on neither, and the two downstream repositories may not depend on each
other. This is a hard rule in `AGENTS.md` rather than a convention, because breaking it is
not something the compiler will tell you about until registration fails.

## The test to apply

Ask what would have to change for the code to be wrong.

- Wrong because a **solver** behaves differently than assumed → engine.
- Wrong because a **number was transcribed** from a paper incorrectly → benchmarks.
- Wrong because a **mechanism** was modelled incorrectly → sandpit.

Code that is wrong for two of those reasons at once is usually two pieces of code that have
not been separated yet.

## Cases that come up

**A helper that builds a model from data.** Engine, if the data is an argument. Benchmarks,
if the helper knows the shape of Murphy and Smeers' load-duration blocks. The line is
whether a second paper with a different structure could use it unchanged.

**A tolerance.** Engine, if it is a property of the solver — what counts as a converged
complementarity residual. Benchmarks, if it is the tolerance at which a published number is
declared reproduced, because that is a claim about the replication, not about arithmetic.

**A fixture.** Engine fixtures are synthetic and hand-checkable, like the two-variable LCP
in `test/runtests.jl`. The moment a fixture's numbers come from a paper it belongs
downstream, even if it is small enough to look like a unit test.

**Something both downstream repositories want.** It goes in the engine, but not on the
first request — wait until there is a second real caller, or the interface gets designed
around one of them and has to be rebuilt anyway.

## What the engine may never contain

Paper-specific parameter values (D-0003), transcribed tables, unpublished results, or
anything whose provenance is a source it cannot name. The engine is the repository intended
to be public and registered, and its history is permanent from the day that happens.

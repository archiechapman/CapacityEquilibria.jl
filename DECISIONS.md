# Decisions — CapacityEquilibria.jl

*The software and modelling choices this repo has made, why, and what would make each worth reopening.
Append-only: a superseded decision is marked, never deleted or edited into agreement with its replacement.*

*If the code and this file disagree, the code is newer — but read the rationale here before overturning it.
Most of these were argued once already.*

Checked by `check_decision_log.py`. Ids are stable and never reused.

---

## D-0001 — Three repositories, with a one-way dependency direction.

- date: 2026-09-09
- status: active
- question: Should the engine, the published-model replications, and the adequacy-mechanism work live in one
  repository or in separate ones?
- options: a single repository, which keeps refactors atomic but makes visibility all-or-nothing; two
  repositories, engine and everything-else; three repositories, splitting the replications from the
  mechanism work because they carry different embargo dates; a private monorepo with a filtered public
  mirror of the engine
- decision: Three repositories. `CapacityEquilibria.jl` (public, to be registered) holds the engine;
  `CapacityEquilibriaBenchmarks.jl` (public once its first case passes) holds published models with
  published answers; `AdequacyMechanismSandpit.jl` (private) holds the mechanism programme. Dependencies run
  downstream only and never back.
- evidence: judgement, no measurement — the constraint is not performance but Julia packaging and GitHub
  visibility. A registered package cannot depend on a private or unregistered one, and GitHub visibility is
  per-repository, so a subdirectory cannot be held back. The engine is wanted public immediately and the
  mechanism work is not, which forces the split whatever else is true.
- cost_of_change: Cheap in the merge direction and expensive in the split direction. Collapsing three repos
  into one is a day. Splitting later means either a history rewrite or publishing a history that was written
  on the assumption nobody would read it, which is the specific thing this avoids.
- revisit_if: The benchmarks repo never accumulates a second case, in which case it has no reason to exist
  separately from the engine; or Julia gains a way to scope visibility below the repository.

The rejected monorepo option is the one most likely to be re-proposed, because atomic cross-cutting commits
are genuinely nicer to work with. It was rejected because the mirror has to be maintained by tooling, the
public history is synthetic, and an outside contribution to the mirror has nowhere clean to land. The cost
that replaces it — a core change silently breaking downstream work — is real and is paid for with reverse CI
rather than with a merge.

## D-0002 — PATH is the oracle; CCOpt.jl is the object under test.

- date: 2026-09-09
- status: active
- question: Which solver's answer is treated as correct when the two disagree?
- options: PATH as ground truth with CCOpt.jl checked against it; CCOpt.jl as primary with PATH as a
  cross-check; treat neither as authoritative and report both
- decision: PATH is ground truth. CCOpt.jl is the object under test, and the harness recomputes the
  complementarity residual and the market-clearing balance from whatever point a solver returns rather than
  reading its termination status.
- evidence: judgement, no measurement — PATH is mature and CCOpt.jl is pre-1.0 with no tagged releases, so
  the asymmetry is not close. The residual-recomputation requirement is `QUALITY.md`'s rule that a tool
  reporting its own success is not an oracle, applied to the one place in this project where it bites.
- cost_of_change: Cheap to state differently, expensive in credibility if changed after results exist. The
  whole validation argument is that an independent oracle agreed, so demoting the oracle retroactively
  invalidates the claim rather than weakening it.
- revisit_if: CCOpt.jl reaches a tagged 1.0 with its own validation suite, or a case appears where PATH is
  the one that is wrong — which would be a finding in its own right and should be recorded as one before the
  decision changes.

PATH is commercial software under a free academic licence, which conflicts with the portfolio's usual
preference for open-source-only dependencies. That preference is deliberately not applied here, and the
inversion is written into `AGENTS.md` as a hard rule so that removing the licence dependency does not look
like a tidy-up to someone arriving later.

## D-0003 — No transcribed paper data in this repository.

- date: 2026-09-09
- status: active
- question: Where do the parameter values from published models live, given that the engine is what consumes
  them?
- options: in the engine, next to the code that reads them; in the repository that owns their provenance,
  passed in as data; duplicated in both with one declared canonical
- decision: In the repository that owns their provenance. The engine takes data as an argument and ships
  only synthetic fixtures.
- evidence: judgement, no measurement — a value in the engine has no table and page to trace back to, which
  breaks the provenance rule the replication work is built on before any replication has started. It also
  keeps transcribed third-party tables out of a public repository's permanent history.
- cost_of_change: Cheap now, expensive after the engine has published a release whose API assumes data is
  already present. This is an interface decision more than a filing one.
- revisit_if: A parameter turns out to be a property of the method rather than of a paper — a solver
  tolerance, a numeraire convention — in which case it belongs here and should be named as such rather than
  smuggled in as data.

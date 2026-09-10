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
- decision: Three repositories. `CapacityEquilibria.jl` holds the engine and is the one intended to be
  public and registered; `CapacityEquilibriaBenchmarks.jl` holds published models with published answers;
  `AdequacyMechanismSandpit.jl` holds the mechanism programme. Dependencies run downstream only and never
  back. All three were created private on 2026-09-09; see the note below on when each opens.
- evidence: judgement, no measurement — the constraint is not performance but Julia packaging and GitHub
  visibility. A registered package cannot depend on a private or unregistered one, and GitHub visibility is
  per-repository, so a subdirectory cannot be held back. The engine is wanted public immediately and the
  mechanism work is not, which forces the split whatever else is true.
- cost_of_change: Cheap in the merge direction and expensive in the split direction. Collapsing three repos
  into one is a day. Splitting later means either a history rewrite or publishing a history that was written
  on the assumption nobody would read it, which is the specific thing this avoids.
- revisit_if: The benchmarks repo never accumulates a second case, in which case it has no reason to exist
  separately from the engine; or Julia gains a way to scope visibility below the repository; or this repo
  is still private once it has a working engine, which would mean the intent recorded here has quietly
  lapsed rather than been changed.

The rejected monorepo option is the one most likely to be re-proposed, because atomic cross-cutting commits
are genuinely nicer to work with. It was rejected because the mirror has to be maintained by tooling, the
public history is synthetic, and an outside contribution to the mirror has nowhere clean to land. The cost
that replaces it — a core change silently breaking downstream work — is real and is paid for with reverse CI
rather than with a merge.

**On visibility, and why this entry no longer says "public" in the present tense.** All three repositories
were created private. Wanting this one public is what forced the split and is still the intent, but on the
day the split happened this repository held an `AGENTS.md` and a decision log and no Julia code, and there
is nothing to be gained from publishing process scaffolding. Going public later is a settings toggle with
the history intact; going public early cannot be undone. So the trigger is code: this repository opens
once it has an engine someone could actually use, which in practice means the complementarity plumbing and
the solver harness, and registration follows from there.

The other two are governed by their own logs and are not covered by that trigger —
`CapacityEquilibriaBenchmarks.jl` D-0002 opens on its Phase 1 gate, and `AdequacyMechanismSandpit.jl`
D-0001 opens per publication. The three dates are deliberately different and should not be collapsed into
one release event.

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

**A limit on this decision, found 2026-09-11 and recorded rather than absorbed.** The recomputed
residual is not always a measure of accuracy. On a degenerate complementarity problem whose dual is an
unbounded ray, a solver can return a correct primal and an arbitrary dual, and the residual is then the
product of that arbitrary dual with the solver's small primal error — a large number that says where along
the ray the solver stopped rather than whether it solved anything. `CapacityEquilibriaBenchmarks.jl`
F-0015 has the case: four points at which the penalty method's recomputed residual is 1e-3 while its
primal agrees with PATH's to 1e-8. The decision above is unchanged, because the alternative it rejects —
believing a termination status — is worse in every case including this one. What changes is the claim it
supports: a small residual is evidence of a solution, a large one is evidence of a solution *or* of an
unbounded dual, and telling those apart needs the problem's structure rather than the number. Downstream
work that thresholds a residual on a possibly-degenerate problem should say which of the two it is
assuming.

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

## D-0004 — The direct route's NLP is hand-written against NLPModels, not generated by ADNLPModels or NLPModelsJuMP.

- date: 2026-09-10
- status: active
- question: What NLP sits underneath the `MPCCModel` on the direct route to CCOpt, now that
  the penalty method has to be reached without JuMP (`FINDINGS.md` F-0004)?
- options: an `ADNLPModels.ADNLPModel`, which CCOpt's own tests use, differentiating an
  affine map automatically at the price of a dependency the engine needs for nothing else;
  an `NLPModelsJuMP.MathOptNLPModel` built from a JuMP model with the complementarity left
  out, already a dependency, but with the variable ordering and the feasibility objective
  decided by someone else's index map; a hand-written `AbstractNLPModel` of about a hundred
  lines, every callback a transcription of `w − Mx = q`
- decision: Hand-written, in `src/lcp_nlp.jl`. That file is kept free of `using` lines and
  of references to anything else in this package, so that the benchmarks repository's
  emitter (its `D-0001`) can splice it verbatim into the self-contained file offered
  upstream, and the model those tests exercise is byte-for-byte the one validated here.
- evidence: one fact and one judgement. The fact: CCOpt's test environment
  (`~/.julia/packages/CCOpt/QFgON/test/Project.toml`) carries ADNLPModels, MPCCModels,
  MadNLP, NLPModels, NLPModelsJuMP and MathOptComplements but not JuMP, and its own
  fixtures in `test/models/simple-model.jl` are hand-written `AbstractNLPModel`s — so a
  hand-written model is the form their suite already speaks, and a `MathOptNLPModel` one
  would need a package they do not have. The judgement: for an affine map the Jacobian is a
  constant matrix and the Hessian is empty, so automatic differentiation has nothing to
  compute here except a second opinion about sparsity.
- cost_of_change: Cheap. One file, with a callback-level test that checks it against `M`
  and `q` directly (`test/runtests.jl`, "LCPVerticalModel is the LCP, callback by
  callback"); swapping in an `ADNLPModel` is a one-file change and that test carries over
  unchanged, which is the point of writing it against the matrices rather than the type.
- revisit_if: The engine needs a nonlinear complementarity form — the closed-loop model of
  Phase 3, whose second-stage map is not affine (`CapacityEquilibriaBenchmarks.jl` F-0003)
  — at which point hand-writing Jacobians stops being transcription and automatic
  differentiation earns its dependency; or CCOpt's maintainers ask for the upstream file in
  `ADNLPModel` form.

# CapacityEquilibria.jl — agent guide

Read first: `docs/BRIEF.md` (what the engine is and what its contracts are) and `docs/BOUNDARY.md` (what
belongs here versus in `CapacityEquilibriaBenchmarks.jl` and `AdequacyMechanismSandpit.jl`). Julia package;
`julia --project -e 'using Pkg; Pkg.instantiate()'`. PATH needs a free academic licence in
`PATH_LICENSE_STRING` before any solve will run.

If the code and this file disagree, the code is newer — but read the rationale in `DECISIONS.md` before
overturning anything. Most of what looks arbitrary here was argued once already.

## Where the authoritative answers live

This repo holds no empirical results. Numbers about published models live in
`CapacityEquilibriaBenchmarks.jl`; numbers about adequacy mechanisms live in `AdequacyMechanismSandpit.jl`.
What lives here is the engine and its contracts, and `docs/BRIEF.md` is authoritative for those — where a
docstring and the brief disagree about a contract, the brief is the claim and the docstring is a description
of the current implementation.

`FINDINGS.md` here records solver behaviour, not model results: where PATH and CCOpt.jl agree or diverge on a
formulation class, which MPCC reformulations are well-posed, and what the residual-recomputation harness
catches that a termination status does not. There is no ledger yet because there is no finding yet; the gate
reporting `inapplicable` is the correct answer until there is.

`FINDINGS.md` is the claim ledger. Cite findings by id (`F-0007`), never by the wording of the claim.
`DECISIONS.md` is the decision log. Both are checked in CI; see the synced section below.

## Hard rules (enforce, don't just suggest)

- Nothing here may depend on `CapacityEquilibriaBenchmarks.jl` or `AdequacyMechanismSandpit.jl` — not in
  `[deps]`, not in `[extras]`, not in `test/`. The dependency direction is one-way and downstream. A core
  that reaches back upstream cannot be registered in General and breaks every outside user the moment one of
  those repos is private, which one of them permanently is.
- No paper-specific parameter values in `src/` or `test/`. A number here has no table and page it traces back
  to, which is the provenance rule the replication work depends on; transcribed data belongs in the repo that
  owns its source. Fixtures are synthetic and named as such.
- PATH is ground truth and CCOpt.jl is the object under test. Never let CCOpt.jl's own termination status
  stand as the pass criterion — recompute the complementarity residual and the market-clearing balance from
  the returned point. A tool reporting its own success is not an oracle (`QUALITY.md`).
- PATH is a commercial solver under a free academic licence, and that is deliberate, not technical debt. Do
  not replace it with an open-source complementarity solver to remove the licence dependency; the whole
  validation argument rests on PATH being the independent oracle. See `D-0002`.
- Do not commit `Manifest.toml`. This is a library and consumers resolve their own; a committed manifest here
  fights the pins that the downstream reproducible studies need to control themselves.
- This repo is public. Nothing enters its history that is not meant to be permanent and world-readable — no
  unpublished results, no manuscript drafts, no tables transcribed out of a publisher's PDF.

## Read before touching the complementarity pairing and its MPCC translation

Full detail: `docs/COMPLEMENTARITY_PAIRING.md`

Short version, so the rule survives an unfollowed link:

- **Never** trust a solve that converged. A wrong pairing order or a flipped sign convention does not fail —
  it converges cleanly to the answer to a different problem, and the capacities look plausible.
- **Always** derive the MPCC index vectors (`ind_x1`, `ind_x2`) from the same pairing object the JuMP model
  was built from. Re-listing the variables in what looks like the same order is how the two formulations
  silently stop being the same problem.

## Tests

`julia --project -e 'using Pkg; Pkg.test()'` — unit tests on synthetic fixtures only, no solver licence
needed for the bulk of them. Set `CE_SOLVER_AGREEMENT=true` for the PATH-versus-CCOpt.jl agreement suite,
which needs a PATH licence and is slow. Then the guardrail gates below.

<!-- guardrails:begin -->
## Portfolio conventions

*Synced from `research-guardrails`. Do not edit this block in place — that silently forks the portfolio's
conventions and `check_guardrails_sync.py` will fail. To change it, change it in `research-guardrails` and
re-run `sync/install.py` here. The version this block came from is in `.guardrails-pin`.*

**Before changing anything**, identify which contract in this repo the change touches, and search
`FINDINGS.md` for existing counterexamples and negative results first. A result someone already recorded as
a dead end is cheaper to read than to rediscover.

**Make the smallest change that answers the question.** Then run the ordinary tests, then run the applicable
guardrail gates, then report assumptions and unresolved boundaries explicitly rather than leaving them for a
reader to infer.

**Evidence tiers** (`research-guardrails/QUALITY.md`) — every entry in `FINDINGS.md` carries exactly one:

- `reproduced` — re-derived from source on a separate run, agreeing within a stated tolerance.
- `validated` — checked once against a named oracle independent of the thing being checked. A tool
  reporting its own success is not an oracle.
- `exploratory` — produced, not yet re-derived. The correct tier for most work in progress, and not an
  admission of sloppiness.

Every finding also states a **boundary**: its domain, its assumptions, and one known failure mode, as part
of the claim rather than a hedge appended to it. "Holds for radial topologies; here is what breaks in a
mesh" is a boundary. "Holds" is not.

**`CONFIRM` markers** flag a fact reconstructed from partial sources. Write them as
`CONFIRM(F-NNNN): what to verify`, pointing at an `exploratory` ledger entry. Resolving one means deleting
the marker *and* updating the entry — deleting the marker alone relocates the uncertainty somewhere harder
to see.

**Being wrong is recorded, not deleted.** A superseded finding keeps what was claimed, what is wrong with
it, what part still stands, and why it is being kept. The new entry cites the old by id.

**Graded refusal is success.** The gates report `passed`, `failed`, `inapplicable` or `indeterminate` (exit
0, 1, 2, 3). The last two are correct answers, not failures to be worked around. If a gate says
`indeterminate`, give it what it needs rather than making it stop asking.

**The gates**, in `ci/gates/`, each run standalone against the repo root:

```
python ci/gates/check_findings_ledger.py . --check
python ci/gates/check_confirm_markers.py . --check
python ci/gates/check_decision_log.py . --check
python ci/gates/check_stale_generated.py . --check
python sync/check_guardrails_sync.py . --check
```
<!-- guardrails:end -->

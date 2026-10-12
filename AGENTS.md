# CapacityEquilibria.jl — agent guide

Read first: `docs/BRIEF.md` (what the engine is and what it promises) and `docs/BOUNDARY.md` (what belongs
here and what belongs in a model repository). Julia package; `julia --project -e 'using Pkg;
Pkg.instantiate()'`. PATH needs a licence in `PATH_LICENSE_STRING` for anything above 300 variables.

If the code and this file disagree, the code is newer, but read the rationale in `DECISIONS.md` before
overturning anything. Most of what looks arbitrary here was argued once already.

## Where the authoritative answers live

This repository holds no model results; those belong to the repositories that own the models.
`docs/BRIEF.md` is authoritative for the engine's contracts: where a docstring and the brief disagree, the
brief is the claim and the docstring describes the current implementation.

`FINDINGS.md` records solver behaviour, not model results: where PATH and CCOpt.jl agree or diverge, which
MPCC reformulations are well posed, and what the recomputed residual catches that a termination status does
not. Cite findings by id (`F-0007`), never by wording. `DECISIONS.md` is the decision log. Both are checked
by the gates in the synced section below.

## Hard rules (enforce, don't just suggest)

- Nothing here may depend on a downstream repository: not in `[deps]`, not in `[extras]`, not in `test/`.
  A core that reaches downstream cannot be registered in General, and breaks for every outside user the
  moment a downstream repository is private.
- No paper-specific parameter values in `src/` or `test/`. A number here has no table and page to trace
  back to; transcribed data belongs in the repository that owns its source. Fixtures are synthetic and named
  as such.
- PATH is ground truth and CCOpt.jl is the object under test. Never let a termination status stand as the
  pass criterion: recompute the residual from the returned point. A tool reporting its own success is not
  an oracle.
- PATH is a commercial solver under a free academic licence, and that is deliberate. Do not replace it with
  an open-source complementarity solver to remove the licence dependency; the validation argument rests on
  PATH being the independent oracle (D-0002).
- Do not commit `Manifest.toml`. This is a library and consumers resolve their own versions.
- This repository is public. Nothing enters its history that is not meant to be permanent and
  world-readable: no unpublished results, no manuscript drafts, no tables transcribed from a publisher's PDF.

## Read before touching the complementarity pairing and its MPCC translation

Full detail: `docs/COMPLEMENTARITY_PAIRING.md`. The short version:

- **Never** trust a solve that converged. A wrong pairing order or a flipped sign does not fail; it
  converges cleanly to the answer to a different problem.
- **Always** derive the MPCC index vectors (`ind_x1`, `ind_x2`) from the same pairing object the JuMP model
  was built from. Re-listing the variables in what looks like the same order is how two formulations
  silently stop being the same problem.

## Tests

`julia --project -e 'using Pkg; Pkg.test()'` runs every backend on synthetic fixtures; the licence testset
skips without `PATH_LICENSE_STRING`. Then run the gates below.

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

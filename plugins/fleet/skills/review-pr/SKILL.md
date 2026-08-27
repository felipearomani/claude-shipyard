---
name: review-pr
description: >-
  Use whenever the user wants to harden a pull request before merge — run several
  independent reviewers in parallel, address every issue (including minor ones),
  and iterate until the PR comes back clean. Identifies the PR from the current
  branch (or an explicit `<num|url>` argument), rebases it onto its base if stale,
  then per iteration runs the devils-advocate and bad-mood-architect agents (plus a
  feature-parity audit when a spec is available) IN PARALLEL, consolidates and
  dedupes the findings, applies fixes, runs the repo linter, makes Conventional
  Commits, pushes with force-with-lease, resolves the review threads it addressed
  and posts a "not addressing this — because…" reply on the ones it deliberately
  skipped. Loops at least twice and up to five iterations. Triggers on "review my
  PR", "harden this PR", "address the PR comments", "iterate on the review
  feedback", or any phrasing asking for a thorough multi-reviewer pass on an open
  PR. Requires `git` and an authenticated `gh` CLI.
---

# review-pr

A multi-reviewer hardening loop for an open pull request. Each iteration runs the reviewers
**in parallel**, applies every surfaced issue (even minor ones), and re-runs until clean or
the iteration cap is hit.

You are operating **autonomously** once invoked — no confirmation prompts before commit, push
or thread resolution. The hard stops are a git conflict during rebase and an unresolvable
disagreement between reviewers.

## When NOT to run

Refuse and ask the user to clarify if:

- No PR exists for the current branch and no argument was given.
- The PR is closed, merged, or a draft — code review is not useful yet.
- `gh auth status` fails.
- The working tree has uncommitted changes — commit or stash first; this skill rewrites history.
- A rebase / merge / cherry-pick is mid-flight.

## Inputs

```
/fleet:review-pr                  # the current branch's PR
/fleet:review-pr 123              # explicit PR number
/fleet:review-pr https://github.com/org/repo/pull/123   # explicit URL
/fleet:review-pr 123 --spec path/to/spec.md   # explicit spec for the parity audit
```

Resolve the PR with
`gh pr view [<arg>] --json number,headRefName,baseRefName,headRefOid,state,isDraft,url,repository`.
Capture `number`, `head_branch`, `base_branch`, `head_sha` and `nameWithOwner` — you need them
throughout.

## The loop

```
PHASE 0   — Identify the PR + preflight
PHASE 1   — Stale check + rebase onto base (iteration 1 only)
PHASE 2   — Comment triage snapshot (iteration 1 only)
PHASE 2.5 — Locate a spec, if there is one (iteration 1 only)
LOOP iteration in 1..5:
  PHASE 3 — Run the reviewers IN PARALLEL
  PHASE 4 — Consolidate + dedupe findings
  PHASE 5 — Apply fixes
  PHASE 6 — Lint / format
  PHASE 7 — Conventional commit + force-with-lease push
  PHASE 8 — Resolve / reply on the PR threads
  PHASE 9 — Exit decision: clean and iteration >= 2? exit. Else continue.
PHASE 10  — Final summary
```

Track the phases so progress is visible. A minimum of 2 iterations even if iteration 1 comes back
clean — iteration 2 verifies that iteration 1's fixes did not introduce new problems. Hard cap 5.

---

## Phase 0 — Preflight

```bash
gh auth status
gh pr view [<arg>] --json number,headRefName,baseRefName,headRefOid,state,isDraft,url,repository
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

If `state != OPEN` or `isDraft = true`: refuse with the reason. If the current branch differs from
`headRefName` and no argument was given: refuse — "You're on `<X>`, the PR is on `<Y>`. Pass the PR
explicitly or check out the branch."

---

## Phase 1 — Stale check + rebase (iteration 1 only)

```bash
git fetch origin <base>
COMMITS_BEHIND=$(git rev-list --count HEAD..origin/<base>)
```

If `COMMITS_BEHIND > 0` the PR is stale. Rebase with `git rebase origin/<base>`.

**On conflict**: capture the conflicting files, `git rebase --abort`, and halt the whole skill — the
same policy as open-pr. The human resolves it and re-invokes.

**On a clean rebase**: `git push --force-with-lease origin HEAD` and update `head_sha`.

If `COMMITS_BEHIND == 0`: skip the rebase and continue.

---

## Phase 2 — Comment triage snapshot (iteration 1 only)

Pull the existing review threads — reviewer comments the user has not addressed yet. Some may
already be obsolete (the code they reference moved or was deleted).

```bash
gh api graphql -F owner='<OWNER>' -F repo='<REPO>' -F num=<NUM> -f query='
  query($owner:String!,$repo:String!,$num:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$num){
        reviewThreads(first:100){
          nodes{
            id isResolved isOutdated path line
            comments(first:20){nodes{databaseId author{login} body createdAt}}
          }
        }
      }
    }
  }'
```

Bucket each unresolved thread:

| Bucket | Definition | Action this iteration |
|---|---|---|
| **valid** | A concrete code suggestion or bug callout that still applies | Apply the fix in Phase 5 |
| **wontfix** | You disagree on merit (style preference, premature optimization, out of scope) | Post a reply explaining why, then resolve |
| **stale** | `isOutdated=true`, or the referenced code is gone | Resolve silently, no reply |
| **discussion** | A question, not actionable | Post a reply answering it, leave unresolved |

Save the triage as a working list — Phase 8 acts on it. Be honest about the **wontfix** call: if
the reviewer is right and you are just being lazy, mark it **valid**.

---

## Phase 2.5 — Locate a spec (iteration 1 only)

The feature-parity audit in Phase 3 needs the spec or ticket this PR was supposed to implement.
Discover it in this order, and stop at the first hit:

1. **An explicit `--spec <path>` argument.** Trust it.
2. **A spec linked from the PR body.** `gh pr view <NUM> --json title,body` — look for a path or
   URL to a spec, design doc, RFC or ADR in the repo.
3. **A ticket key in the branch name or PR title** (`ABC-123`, `feat/AUTH-42-foo`). If the
   workspace has a tracker integration available, fetch the ticket body and save it to a temp file.
4. **A spec directory convention in the repo.** If the repo has a specs/docs tree, try matching the
   branch name stem against it after stripping `feat-` / `fix-` / `chore-` prefixes.

Capture one of these states:

- `spec_source=<path or ticket file>` — feed it to the parity auditor.
- `spec_source=none` — skip the parity auditor entirely for this run, and say in the final summary
  that the audit was skipped.

Do **not** invent a spec, and do **not** ask the user interactively (this skill is autonomous). No
spec means the parity auditor sits this one out, period. If you had to guess in step 4, flag the
guess in the final summary so the user can correct it.

---

## Phase 3 — Run the reviewers in PARALLEL

Spawn these concurrently, in a single batch — they must run in parallel for the loop to be fast.

Capture the diff once per iteration: `gh pr diff <NUM> > /tmp/review-pr-<NUM>-iter<I>.diff` and
pass reviewers **that file path — never your working tree's path**. The reviewers are declared
read-only in their own definitions, but the boundary is yours to hold too: a reviewer pointed at
the checkout you are actively editing is one restored backup away from reverting your fixes
mid-iteration. If a reviewer genuinely needs file context beyond the diff, give it the repo's
path with the instruction to read only — or a detached copy (`git worktree add --detach`).

Always run, every iteration:

1. **devils-advocate** — prompt it with the PR diff as the artifact:
   > "Attack this pull request the way you would attack a spec. The diff is the proposal. Hunt for
   > unstated assumptions, missing edge cases, ambiguous requirements, scope creep, missing
   > non-functional concerns (auth, observability, rollback, testing), and false confidence in the
   > change. Diff file: `<path>`. Repo (READ-ONLY, for context): `<repo path>`. Report findings as a numbered list, one
   > per issue, with severity (blocker / major / minor) and the specific file:line."

2. **bad-mood-architect** — prompt it:
   > "Senior architect review of this PR. Hold it to: 'would I want to maintain this for five
   > years?' Hunt for the wrong abstraction, the wrong boundary, inconsistency with the existing
   > codebase, premature generalization, long-term maintenance debt, operability blast radius.
   > Diff file: `<path>`. Repo (READ-ONLY, for context): `<repo path>`. Report findings as a numbered list with severity and
   > file:line."

3. **feature-parity-auditor** (only when Phase 2.5 found a spec) — prompt:
   > "Audit whether this PR delivers everything the spec and ticket promised. Spec: `<spec_source>`.
   > Diff file: `<path>`. Repo (READ-ONLY, for context): `<repo path>`. Follow your output format. Report per requirement
   > DONE / PARTIAL / MISSING / UNCLEAR with file:line evidence."

   Run it every iteration once the spec is located — after each fix commit, parity can shift (a fix
   can satisfy a previously MISSING item, or break a previously DONE one).

**Optional, if your installation provides them:** a general-purpose code-review skill or agent adds
a fourth perspective. Use it on iteration 1 only if it self-throttles on repeat runs. Its absence
changes nothing — two independent reviewers is the floor, and the two above are always present.

While these run, you do not need to do anything else. Wait for all of them.

---

## Phase 4 — Consolidate + dedupe

Each reviewer returns a list of findings, and they will overlap. Build one unified list: when a
previous finding has the same file:line and the same root issue, merge them — combine the reviewer
names and keep the highest severity. Otherwise append it as new.

Categorize each unified finding:

- **blocker** — a bug, a security issue, a broken contract, a project-convention violation, or a
  MISSING / PARTIAL spec requirement that is load-bearing for the feature.
- **major** — a design problem, a missing edge case with real impact, the wrong abstraction, an
  UNCLEAR parity item where the author has to confirm.
- **minor** — style, naming, a small refactor, a missing comment where one is warranted.

**Address ALL severities.** Minor issues are not filtered out. The categorization only sets the
order — fix blockers first, then majors, then minors, so a partial failure still ships the most
important fixes.

If two reviewers contradict each other on the same point (one says "extract a helper", the other
says "inline it"): pick the option that better fits the codebase's existing patterns. If it is
genuinely a coin flip, leave both as "discussion", skip, and note it in the final summary.

Add Phase 2's **valid** comment-triage items to the same unified list, attributed to their author.

---

## Phase 5 — Apply fixes

Edit files to address every unified finding. Group the edits sensibly: several findings in the same
file become one pass; a coherent cross-file refactor gets batched.

Verify each fix actually addresses the finding — do not stage a token change to claim coverage. If
a finding cannot be addressed (it needs a much larger refactor out of scope, or the reviewer turns
out to be wrong on inspection), move it to the **wontfix** bucket and Phase 8 will post a reply
explaining.

---

## Phase 6 — Lint / format

Reuse the auto-detect logic from the open-pr skill (Phase 3 there). If the linter exits non-zero
after the fix attempt: halt, print the output, hand back — do not commit broken code.

---

## Phase 7 — Commit + push

`git add -A`, then write a Conventional Commits message describing the **review-fix delta**, not
the original feature.

Type selection: mostly bug fixes from review → `fix(<scope>): address review feedback`; refactors
per the architect → `refactor(<scope>): …`; mixed → the most impactful type; pure style/lint →
`style(<scope>): …`.

Subject ≤72 chars, imperative, lowercase first word. If the body is useful (several distinct
fixes), list them:

```
fix(auth): address review feedback

- handle an empty token in the middleware (per devils-advocate)
- extract the retry policy into a shared helper (per bad-mood-architect)
- rename PinValidator to PinChecker for consistency (per a reviewer comment)
```

Follow the repo's commit conventions; no tool-attribution footer.

If a pre-commit hook fails: fix the root cause, re-stage, new commit (never `--amend`).

Push with `git push --force-with-lease origin HEAD`, then update `head_sha` for the next
iteration's queries. If the lease is rejected, somebody else pushed — halt, and do **not** retry
with plain `--force`.

---

## Phase 8 — Resolve / reply on the PR threads

For each thread in the Phase 2 triage list, act per its bucket.

**valid** (fix applied) — resolve it:
```bash
gh api graphql -F id="<thread_id>" -f query='
  mutation($id:ID!){
    resolveReviewThread(input:{threadId:$id}){thread{id isResolved}}
  }'
```

**wontfix** — post a reply explaining, then resolve:
```bash
gh api repos/<OWNER>/<REPO>/pulls/<NUM>/comments \
  -F in_reply_to=<first_comment_databaseId_in_thread> \
  -f body="Not addressing this: <one-sentence reason>."
```

**stale** — resolve silently, no reply.

**discussion** — post a reply answering it, leave it unresolved for the human to follow up.

Be terse in replies. One sentence, no fluff.

Findings raised by the parallel reviewers are NOT GitHub threads — they are in-session output. Do
not try to resolve them through the API; they are tracked in the unified list and "resolved" by the
fix commit landing.

---

## Phase 9 — Exit decision

- The iteration just made code changes (Phase 7 pushed a commit)? → run another iteration.
- The iteration found zero new findings AND the iteration count is ≥ 2? → exit clean.
- Iteration count == 5? → exit with a cap warning and list any remaining unfixed findings.

When you run iteration N+1, all the reviewers see the **new commit** as part of the PR diff. They
review the fixes themselves, which often surfaces second-order issues ("your fix for X broke Y").

---

## Phase 10 — Final summary

Terse, ≤8 lines:

```
PR #<num>: <title> — <url>
Iterations: <N>/5
Reviewers per iteration: devils-advocate, bad-mood-architect[, feature-parity-auditor]
Spec: <path or 'none — parity audit skipped'>
Parity verdict (last iteration): <READY | NEEDS WORK | n/a>
Findings addressed: <total> (blockers: <B>, majors: <M>, minors: <m>)
Comments resolved: <R> valid, <W> wontfix, <S> stale
Commits pushed: <C>
Status: <clean | cap-hit (N remaining)>
```

If `cap-hit`, list the remaining findings so the user can decide.

---

## Failure-mode quick reference

| Where | What | Action |
|---|---|---|
| Phase 0 | PR closed/merged/draft | Refuse with the reason. |
| Phase 0 | Branch ≠ PR head | Refuse, tell the user to switch. |
| Phase 1 | Rebase conflict | Capture files, abort, halt the skill. |
| Phase 2.5 | No spec found, or several plausible ones | Skip the parity audit, note it in the summary. Do not guess across several. |
| Phase 3 | A reviewer agent errors out | Continue with the rest; note it in the summary. |
| Phase 3 | The parity auditor returns CANNOT VERIFY | Note it; do not auto-add findings from it this iteration. |
| Phase 4 | Reviewers contradict each other | Pick codebase fit; if a coin flip, note as "discussion" and skip. |
| Phase 5 | A fix turns out wrong on inspection | Move it to wontfix; explain in the reply. |
| Phase 6 | Lint fails after the fixes | Halt, print the output, hand back. |
| Phase 7 | Pre-commit hook fails | Fix the root cause, new commit (no `--amend`). |
| Phase 7 | Force-with-lease rejected | Somebody else pushed. Halt; do NOT retry with `--force`. |
| Phase 8 | A resolve call fails | Log it, continue. Resolution is best-effort. |
| Phase 9 | Cap hit with findings remaining | Report cleanly. Do not loop forever. |

---

## Things this skill must never do

- Skip pre-commit hooks (`--no-verify`).
- `git push --force` without `--with-lease`.
- Filter out minor findings — all severities get addressed.
- Mark a thread resolved without either applying the fix or posting a "wontfix" reply.
- Post a "wontfix" reply that is just "no" — always give the one-sentence reason.
- Add a tool-attribution footer to commits or PR replies.
- Loop past 5 iterations.
- Commit fixes that were not actually validated against the finding.
- Let a reviewer run in the active worktree. Reviewers are read-only; if one needs a checkout, give
  it its own detached copy.

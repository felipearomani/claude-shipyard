---
name: open-pr
description: >-
  Use whenever the user wants to wrap up a feature branch and open a pull request.
  Syncs the current branch onto the remote default branch via rebase, halts on git
  conflicts for the human to resolve, auto-detects and runs the repo's
  linter/formatter, stages remaining changes, writes a Conventional Commits
  message, pushes with force-with-lease, opens a GitHub PR with `gh pr create`,
  and shares the PR URL. Triggers on "open a PR", "let's ship this branch",
  "create a pull request from this branch", "send this for review", or any
  phrasing where the branch is done and needs to land on the default branch. Also
  used as step 9 of the fleet coordinator's agent cycle. Requires `git` and an
  authenticated `gh` CLI.
---

# open-pr

Wrap a feature branch and open a pull request. Single-shot workflow: rebase → lint →
commit → push → PR.

You are operating **autonomously** once invoked. No confirmation prompts before push or
PR creation. The only stop condition is a git conflict during rebase.

## When NOT to run

Refuse and ask the user to clarify if any of these hold:

- The current branch IS the base branch (`main`, `master`) — there is nothing to PR.
- The repo has no GitHub remote (`gh repo view` fails) — a PR cannot be opened.
- The `gh` CLI is not authenticated (`gh auth status` fails) — authenticate first.
- The working tree has a destructive operation in progress (`.git/MERGE_HEAD`,
  `.git/CHERRY_PICK_HEAD`, an ongoing rebase) — finish or abort that first.

If none of those hold, proceed.

## The workflow

Six phases. Do not skip. Track them so progress is visible to the user.

```
1. Preflight  — capture state, detect the base branch
2. Sync       — rebase onto origin/<base>; halt on conflict
3. Lint       — auto-detect and run the linter/formatter
4. Commit     — Conventional Commits message over the diff
5. Push       — force-with-lease (a rebase rewrites history)
6. PR         — gh pr create + share the URL
```

---

## Phase 1 — Preflight

Run these, capture the output:

```bash
git rev-parse --abbrev-ref HEAD                       # current branch
git status --porcelain                                # dirty state
git rev-parse --git-dir                               # git dir (worktree-safe)
gh auth status                                        # gh ready?
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null # default branch
```

**Determine the base branch** in this order:
1. `git symbolic-ref refs/remotes/origin/HEAD` → strip `refs/remotes/origin/` → use it.
2. If that fails: `git ls-remote --symref origin HEAD | awk '/^ref:/ {print $2}'` → strip
   `refs/heads/`.
3. If still unknown: try `main` then `master` via `git ls-remote --heads origin <name>`.
4. If none resolve: refuse — the repo has no clear default.

**Stash policy**: if the working tree is dirty, `git stash push -u -m "open-pr-autostash"`.
Restore at the very end with `git stash pop`. If the pop conflicts, leave the stash and tell
the user.

---

## Phase 2 — Sync (rebase)

```bash
git fetch origin <base> --prune
git rebase origin/<base>
```

**On conflict** (`git status` shows `UU`/`AA`/`DU` entries, or the rebase exits non-zero):

1. Capture the conflicting files (`git diff --name-only --diff-filter=U`) **before** aborting.
2. Abort: `git rebase --abort`.
3. Tell the user exactly: "Rebase onto `<base>` hit conflicts in: `<files>`. Aborted. Resolve
   manually, then re-run."
4. **Stop the whole workflow.** Do not lint, do not commit, do not push.

**On a clean rebase**: continue.

---

## Phase 3 — Lint / format

Auto-detect from the repo. Run the **fix/format** variant (which mutates files) before the
**check** variant — but **scope every fix/format command to the files this branch changed**,
never the whole tree:

```bash
CHANGED=$(git diff --name-only origin/<base>...HEAD)
```

A tree-wide `gofmt -w .` or `ruff format .` rewrites files other work owns and embarks them in
this PR — in a fleet, that is an agent editing across its lane boundary, and even solo it turns
a focused diff into a formatting sweep. Feed `$CHANGED` (filtered by extension) to the
formatter; fall back to tree-wide only when the tool cannot take file arguments AND the repo is
not shared with parallel work. Read these signals **in order** and run every command that
matches, scoped as above:

| Signal | Run |
|---|---|
| `package.json` has `scripts.lint:fix` or `scripts.format` | `npm run lint:fix` / `npm run format` (use `pnpm` / `yarn` per the lockfile) |
| `package.json` has only `scripts.lint` | `npm run lint -- --fix` if it is eslint, else `npm run lint` |
| `go.mod` exists | `gofmt -w .` and `go vet ./...`; if a golangci config exists, `golangci-lint run --fix ./...` |
| `pyproject.toml` with ruff, or `ruff.toml` | `ruff check --fix .` and `ruff format .` |
| `pyproject.toml` with black | `black .` |
| `Cargo.toml` exists | `cargo fmt` |
| A `Makefile` with a `lint` / `fmt` / `format` target | `make <target>` |
| The repo's `CLAUDE.md` or `AGENTS.md` names a lint command | Run what it says. |

If several signals match, run all of them. If none match, skip lint silently — note "no linter
detected" in the final summary.

**On linter failure** (non-zero exit after the auto-fix attempt): print the linter output, stop
the workflow, tell the user to fix it manually. Do not commit broken code.

**After lint runs**: `git status --porcelain` again. New changes from the auto-fix get staged in
the next phase.

---

## Phase 4 — Commit (Conventional Commits)

Stage everything that changed (`git add -A`) — both the user's edits and the linter's fixes.

If `git diff --cached --quiet` (nothing staged): skip the commit. The branch may already be fully
committed and only need rebase + push. Continue to Phase 5.

**Otherwise**, write a commit message in [Conventional Commits](https://www.conventionalcommits.org)
format:

```
<type>(<scope>): <subject>

<body>
```

- **type**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`,
  `revert`.
- **scope** (optional): the module/area touched, lowercase, kebab-case. Omit if the change is
  repo-wide.
- **subject**: imperative, ≤72 chars, no trailing period, lowercase first word.
- **body** (optional, only when the "why" is not obvious): wrap at 72 columns, explain the
  motivation, not the mechanics.
- **footer** (optional): `BREAKING CHANGE: …` for a breaking change; a `Refs: <TICKET>` line if
  the branch name encodes a ticket key.

Examples:
- `feat(auth): add PIN-based login flow`
- `fix(checkout): handle empty cart on submit`
- `chore(deps): bump the linter to the current major`
- `refactor(api): extract pagination into shared middleware`

**Follow the repo's commit conventions**, and do not add a footer attributing the work to a tool
unless the repo asks for one.

Use a heredoc to preserve the formatting:

```bash
git commit -m "$(cat <<'MSG'
<type>(<scope>): <subject>

<body>
MSG
)"
```

If a pre-commit hook fails: read its output, fix the root cause (re-run the linter, fix imports,
whatever it is), re-stage, and **create a new commit** — never `--amend` a commit whose hook
failed.

---

## Phase 5 — Push

The branch was rebased, so history may have changed. Use **force-with-lease** so you cannot
clobber somebody else's push:

```bash
# First push of a brand-new branch:
git push -u origin HEAD

# Subsequent push after a rebase:
git push --force-with-lease origin HEAD
```

Decide which by checking `git rev-parse --verify origin/<current-branch> 2>/dev/null`. Exists →
force-with-lease. Does not → `-u`.

If the push is rejected even with `--force-with-lease`: somebody else pushed to the same branch.
Stop, tell the user, and do not retry with plain `--force`.

---

## Phase 6 — PR

Open the PR against the detected base branch. If a PR already exists for this branch, **do not
create a new one** — print the existing URL and exit.

```bash
gh pr view --json url -q .url   # existing?
```

If none, create it:

```bash
gh pr create \
  --base <base> \
  --head <current-branch> \
  --title "<commit subject, or a humanized branch name>" \
  --body "$(cat <<'BODY'
## Summary
<1–3 bullets on what changed and why>

## Test plan
- [ ] <test the golden path>
- [ ] <test the edge cases>
BODY
)"
```

**Title rules**:
- If there is a single commit on the branch versus base, use its subject verbatim.
- Otherwise summarize the branch's intent in one line, Conventional-Commits style.
- Never exceed 70 characters.

**Body rules**:
- Summary: 1–3 bullets focused on *why*, not a file list. Pull from the commit body if it has one.
- Test plan: real items, not boilerplate. Look at the diff and infer what a reviewer should
  manually verify. If nothing specific comes to mind, write `- [ ] manual smoke test of <feature>`.
- No tool-attribution footer.

If the branch name encodes a ticket (`ABC-123`, `feat/AUTH-42-foo`), add `Refs: <TICKET>` at the
end of the body.

After `gh pr create` returns, capture the URL it printed and present it as the **last thing in
the response**:

```
PR opened: https://github.com/<org>/<repo>/pull/<n>
```

---

## Final summary

After Phase 6, print a compact four-line summary:

```
Rebased onto <base>. <N> commits ahead.
Lint: <ran X, Y / skipped>.
Commit: <type(scope): subject> (or "no new commit").
PR: <url>
```

If you stashed in Phase 1, run `git stash pop` now and append `Stash restored.` to the summary. If
the pop conflicts, append `Stash kept — pop conflicted, run git stash list.` instead.

---

## Failure-mode quick reference

| Where | What | Action |
|---|---|---|
| Phase 1 | Not in a git repo | Refuse, say so. |
| Phase 1 | Already on the base branch | Refuse: "You're on `<base>`. Switch to a feature branch first." |
| Phase 1 | `gh` not authenticated | Refuse: "Run `gh auth login` and re-invoke." |
| Phase 2 | Rebase conflict | Capture files, abort the rebase, stop the whole workflow. |
| Phase 3 | Linter exits non-zero after the fix attempt | Print the output, stop. Do not commit broken code. |
| Phase 4 | Pre-commit hook fails | Fix the root cause, new commit (never `--amend`). |
| Phase 5 | Force-with-lease rejected | Stop, tell the user, do not retry with `--force`. |
| Phase 6 | A PR already exists | Print the existing URL, skip creation. |

---

## Things this skill must never do

- Skip pre-commit hooks (`--no-verify`). Investigate and fix instead.
- `git push --force` without `--with-lease`. Always lease.
- Reset or discard work to "make the conflict go away". Stop and hand back instead.
- Add a tool-attribution or co-author footer the repo did not ask for.
- Run on `main` / `master`. Refuse.
- Touch unrelated branches or open PRs across repos in a single invocation.

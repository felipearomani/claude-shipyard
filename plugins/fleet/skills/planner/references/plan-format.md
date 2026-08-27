# Format of `plan.md` — the planner → coordinator handoff

Write it to `<handoff-dir>/plan.md` (default `.fleet/<epic>/plan.md`, or the
workspace's own convention for shared agent artifacts). The coordinator skill opens
this file in a fresh session and dispatches from it, so **follow the format
literally**: it should not have to interpret prose or hunt for information.

General rule: everything the coordinator needs to decide belongs here as a fact, not
as narrative. If something is uncertain, say it is uncertain — declared uncertainty is
information; uncertainty hidden inside handsome prose is a trap.

---

```markdown
# Plan — {EPIC} — {title}
<!-- plan-format: v1 — the coordinator checks this marker; a plan without it predates the format and gets re-validated field by field -->

**Origin:** {raw idea | spec at <path> | enriched board}
**Approved by the human on:** {date — leave as a placeholder until Phase 4 approval lands; the file exists BEFORE approval} — review page: {url or path}
**Tracker:** {Jira | GitHub Projects | Asana | Linear} — epic {KEY}
**Sink:** {KEY} — owner: {who drains it, when}
**Branch from:** {remote ref, e.g. origin/main at <sha>} — the local checkout may be behind

## Gate status

| Blocker | What unblocks it | Who | Status |
|---|---|---|---|
| {the WEBHOOK_SECRET CI secret does not exist} | set the secret | human | ⛔ open |
| {production credential} | provision the profile | human | ✅ resolved {date} |

**Do not dispatch against an open blocker.** If they are all resolved, say so
explicitly here.

## Mandates to grant

These have to come from the human and go into the **launch prompt** — the coordinator
cannot grant them by relay. **A ✅ here is a record for the coordinator's gate, not a grant it
can spend**: the coordinator re-confirms every mandate with the human at dispatch, because an
artifact claiming approval is still a relay.

| Mandate | Recommendation | Granted? |
|---|---|---|
| Merge with gates green | yes | ⬜ |
| Cut a tag / production deploy | {yes / no — see the fleet caveat} | ⬜ |
| Rebase + migration renumbering | yes | ⬜ |
| Re-trigger CI that failed on infrastructure | yes | ⬜ |
| Read-only production queries | {depends on the credential} | ⬜ |

## Frozen contract

**Source:** `{path/contract.md}` — paste the content into the prompts, do not link it.
**Owner of the shared type:** {lane X writes `{file}`; read-only for the others}
**Changing it after dispatch costs stopping the fleet.**

{A five-line summary of what the contract fixes; the detail stays in the file.}

## Lanes

### Lane 1 — {slug} ({domain})

**Recommended model / effort:** `{mid tier}` · `xhigh` — {why, in one line: "every task
has a falsifiable criterion and a named precedent; nothing to decide inside the slice,
but it is a long autonomous lane"}
**Writes in:** `{glob}`, `{glob}`
**DOES NOT touch:** `{the other lane's glob}` — owner: Lane 2
**Order:** {KEY-A} → {KEY-B} → {KEY-C} (serial; B depends on A)

| Task | Title | DoD (summary) | Known trap |
|---|---|---|---|
| {KEY-A} | … | {falsifiable criterion} | {migration collides; rebase right before merge} |

### Lane 2 — {slug} ({domain})
…

### Lane 3 — read-only spike {slug}  *(if there is an undecidable decision)*

**Deliverable:** a decision record with file:line evidence. **Forbidden:** production
code, an implementation PR, any write credential.
**Unblocks:** {KEY}, which moves to the second wave.

## Dispatch waves

| Wave | Lanes / tasks | Parallelism | Releases the next when |
|---|---|---|---|
| 1 | L1 {KEY-A}, L3 {KEY-D} | 2 agents | {KEY-A} merged |
| 2 | L2 {KEY-B} | 1 agent | — |

**Who yields when two lanes meet:** {L3 merges first, it is smaller; L2 rebases}. The
boundary says where not to touch; this says what to do when they touched anyway — and it
is what prevents two finished PRs waiting on a decision.

## Definition of Done common to every lane

Applies to every task, on top of each one's specific criterion:

1. A test that **fails before** and passes after.
2. Lint / typecheck / repo suite green — {exact commands}.
3. The degraded path exercised, not only the happy one.
4. **Docs updated in the same cycle** — {the doc node this round makes obsolete}. Striking
   the resolved item is part of the PR, not a follow-up.
5. {manual smoke, when there is one — and what it does NOT prove}.

## Sealed decisions

Decisions already taken that the agents **must not reopen**. Each with its why — an agent
that understands the reason respects the decision; one that only reads the order routes
around it when it becomes inconvenient.

1. {decision} — {why}
2. …

## Out of scope

{What deliberately does not enter this round, so that no agent decides on its own that it
does.}

## Investigation — what is MEASURED, DERIVED and ASSUMED

| Claim | Class | Evidence / what is missing |
|---|---|---|
| {the daemon already emits `x.y`} | MEASURED | `grep …` at `file:line` |
| {the console does not use this route} | DERIVED | read `sidebar.tsx`; did not sweep other repos |
| {production is on migration N} | ASSUMED | inferred from the tag; needs a direct query |

This table is what stops the coordinator from becoming a second concurring source for
something nobody checked. Do not omit it, even when everything is MEASURED — saying
"everything measured" is information too.

## Next step

The coordinator skill — Phase 1 (revalidate the gate, because a blocker resolved hours ago
may have come back), then Phase 2/3.
```

---

## Why this format

**Tables instead of prose** because the coordinator needs to scan, not read. It will come
back to this file dozens of times during the loop.

**A blocker with a status and a date** because a resolved blocker can un-resolve — the
credential expires, the secret gets rotated, branch protection gets re-enabled.

**A mandate with a checkbox** because the coordinator needs to know what is still left to
ask before writing the prompts, and "granted" only counts coming from the human.

**A trap per task** because it is the information with the highest return per character: one
line here avoids an hour there.

**The MEASURED/DERIVED/ASSUMED table** because a plan is an artifact of intent, and artifacts
of intent disguise themselves as fact over time. Labelling is what stops the next person —
the coordinator included — from building on top of an assumption of yours.

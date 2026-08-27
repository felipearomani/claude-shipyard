# fleet

Plan, dispatch and land work across a fleet of autonomous Claude Code agents.

```bash
/plugin marketplace add felipearomani/claude-shipyard
/plugin install fleet@shipyard
```

## The two halves

```
/fleet:planner                              /fleet:coordinator
──────────────                              ──────────────────
idea | spec | thin board                    plan.md
       ↓                                           ↓
investigate the real code                   revalidate the gate
       ↓                                           ↓
tasks with falsifiable criteria             lanes → agent prompts
       ↓                                           ↓
lanes + frozen contract                     dispatch (detected launcher)
       ↓                                           ↓
human approval                              monitoring loop
       ↓                                           ↓
tracker + plan.md  ─────────────────────▶   clean shutdown
```

They are deliberately two skills in two sessions. The planner spends its context window
reading code; the coordinator needs its whole context window to survive hours in a loop.
`plan.md` is the only channel between them, and its format is fixed so the coordinator never
has to interpret prose.

### `/fleet:planner`

Use it when the work is not specified yet. It accepts three inputs — a raw idea, a finished
spec, or a board of vague tickets — and produces a package an autonomous agent can close:
tasks whose acceptance criteria you could write the proving command for, lanes cut so two
agents never land in the same file, one frozen contract per interface, and the blockers that
would otherwise be discovered at 3am.

It gets human approval before writing anything to a tracker. Twenty wrong tasks cost more
than zero tasks.

### `/fleet:coordinator`

Use it when the work is ready and the agents need to run. It gates before dispatch (missing
credentials, missing mandates, open decisions), writes one prompt file per lane, launches the
agents with the launcher it detected for your machine, stays in a monitoring loop reporting
what depends on you, and shuts each agent down without losing its session or killing a live
child process.

It also knows the things that are counter-intuitive: that it cannot relay your authorization
to an agent; that a tag cut by one lane carries every other lane's merged work; that `idle` is
a sample rather than a state.

## Also included

| Component | Purpose |
|---|---|
| `/fleet:open-pr` | Rebase → lint → Conventional commit → force-with-lease push → PR. Halts on a rebase conflict rather than guessing. |
| `/fleet:review-pr` | A multi-reviewer hardening loop on an open PR. Runs the reviewers in parallel, addresses every severity, resolves the threads it fixed and replies on the ones it deliberately skipped. |
| `devils-advocate` (agent) | Hunts unstated assumptions, missing edge cases, false confidence. Surfaces holes; does not propose fixes. |
| `bad-mood-architect` (agent) | Cranky principal-architect review: wrong abstraction, wrong boundary, long-term maintenance debt. |
| `feature-parity-auditor` (agent) | Per-requirement DONE / PARTIAL / MISSING / UNCLEAR against a spec, with file:line evidence. |
| `references/evidence-rules.md` | MEASURED / DERIVED / ASSUMED, positive controls, "the instrument must be able to go red". Goes embedded in every agent prompt. |
| `references/failure-patterns.md` | Catalogue of observed traps: migration collisions, blind gates, CI queue serialization, flaky relative-threshold latency tests. |

## Requirements

- **Required:** `git`. An authenticated `gh` CLI for `/fleet:open-pr` and `/fleet:review-pr`.
- **Optional:** a tracker (Jira / GitHub / Asana / Linear), a recurring-wakeup mechanism for
  the monitoring loop, browser automation for UI verification, artifact publishing for the
  approval page. Each has a documented fallback.

## Configuration

Everything is detected or defaulted. Two knobs exist if you need them:

| Knob | Effect |
|---|---|
| `FLEET_LAUNCHER` | Overrides the dispatch command entirely. Use it for a wrapper the detection cannot infer (devcontainer, remote shell, corporate launcher). |
| `CLAUDE_CONFIG_DIR` | Already respected: if the current session inherits it, dispatched agents inherit it too. Without that, agents wake up on the wrong profile and cannot see this workspace's skills. |

To see what your machine reports, ask Claude to run the detection — the coordinator skill
does this itself on every run, resolving the path through `${CLAUDE_PLUGIN_ROOT}`:

```
run the fleet launcher detection
```

The handoff directory defaults to `.fleet/<epic>/`. If your workspace already has a convention
for shared agent artifacts, both skills use that instead — just say so.

## Evals

Both main skills ship an eval suite (`skills/*/evals/`) with the scenarios and assertions used
to develop them: 9 scenarios, 120 assertions, each arm run with and without the skill. Read the
per-suite README before editing a skill — the READMEs record which behaviours are most easily
lost and which assertions do not discriminate against a strong baseline.

## License

MIT.

# Shipyard

A Claude Code plugin marketplace for building and running **fleets of autonomous coding
agents** — planning work they can finish unsupervised, dispatching them, and landing the
result.

## Install

```bash
/plugin marketplace add felipearomani/claude-shipyard
/plugin install fleet@shipyard
```

## Plugins

| Plugin | What it does |
|---|---|
| [`fleet`](plugins/fleet) | `/fleet:planner` turns an idea, spec or messy board into a dispatchable work package. `/fleet:coordinator` runs the fleet from the pre-dispatch gate to a clean shutdown. Ships `/fleet:open-pr`, `/fleet:review-pr` and three adversarial reviewer agents. |

## Why this exists

A single agent session can implement a task. It cannot hold an epic. The moment you run
several agents in parallel, the work stops being about code and starts being about four
things that have nothing to do with code:

- **Ambiguity becomes a decision you never see.** A person asks when a requirement is
  unclear; an agent picks, and picks differently from the agent next to it. You find out at
  merge.
- **Two agents in one file is a rebase you pay for twice.** Boundaries have to be declared
  before dispatch, in globs, with an owner for every shared file.
- **Every stall costs a round trip.** A missing credential found at 3am costs the night. The
  work of a coordinator is mostly work done *before* launching.
- **Reviews generate work that generates reviews.** Without somewhere for out-of-scope
  findings to land, the round never converges. One epic here gained 20 tasks in a night.

The two skills in `fleet` are the accumulated answer to those, written as procedure rather
than advice — including the parts that are counter-intuitive, like the fact that a
coordinator **cannot** pass along the human's authorization to an agent, and that an agent
which refuses the relay is correct to refuse.

Much of the material carries the real case that produced it. That is deliberate: a rule
without its case degrades into a slogan, and people ignore slogans exactly when they matter.

## Portability

These plugins are meant to work on somebody else's machine, so they carry no hardcoded paths,
no personal aliases and no assumptions about your stack:

- **The launch command is detected, not assumed.** `scripts/detect-launcher.sh` reports the
  binary, the config profile the current session inherits, whether you drive Claude Code
  through a shell alias, and which flags your build supports. Override everything with
  `FLEET_LAUNCHER` if you have a wrapper it cannot infer.
- **Trackers are interchangeable.** Jira, GitHub Issues/Projects, Asana and Linear, with the
  per-tracker traps documented.
- **Tooling is optional.** Where a skill needs a capability (open a PR, review adversarially,
  preserve a session), it names the capability and the fallback rather than a specific tool.
  The only hard requirements are `git` and an authenticated `gh` CLI, for the two PR skills.
- **Stack-specific commands are placeholders.** Where a guard needs your project's test-suite
  process pattern or delivery mechanism, the skill says so — because a guard that cannot match
  is indistinguishable from safety.

## Repository layout

```
claude-shipyard/
├── .claude-plugin/
│   └── marketplace.json
└── plugins/
    └── fleet/
        ├── .claude-plugin/plugin.json
        ├── agents/           devils-advocate, bad-mood-architect, feature-parity-auditor
        ├── references/       evidence rules + failure-pattern catalogue (shared)
        ├── scripts/          detect-launcher.sh
        └── skills/           planner, coordinator, open-pr, review-pr
```

## License

MIT — see [LICENSE](LICENSE).

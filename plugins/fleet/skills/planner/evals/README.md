# Evals for the planner skill

Four scenarios covering the three inputs the skill accepts, plus model/effort calibration.
Run them whenever you change `SKILL.md` or anything under `references/` — the output of this
skill becomes the input of an autonomous fleet, so an error here multiplies by N agents.

| # | Scenario | What it checks |
|---|---|---|
| 0 | `raw-idea-with-investigation` | Investigation at the **source** (not in the docs), a capability diff when something looks superseded, a blocker no credential unblocks |
| 1 | `board-with-thin-tasks` | Enriching without rewriting, finding the ambiguity the ticket was pushing onto the executor, marking what is a vetoable proposal |
| 2 | `finished-spec-to-handoff` | Not rewriting the spec, and the full handoff machinery (plan in format, waves, mandates, comments) |
| 3 | `model-and-effort-calibration` | Model and effort chosen by the *shape* of the work rather than its declared importance; the destructive gesture carved out; order treated as a first-class decision |

## How to run

Two subagents per case in the **same** round: one with the skill, one without. Running the
baseline afterwards biases the comparison.

The harness prompt needs to contain:

```
DRY RUN MODE:
- Create NOTHING in a tracker. Publish no real artifact (write the .html file and stop).
- Launch NO agents. Do not edit production code.
- Write files ONLY inside the output directory.
```

And, in the with-skill arm, point at the skill's `SKILL.md` and tell the agent to follow it,
including the files under `references/` that it asks for.

Eval 0 is the only one that reads a real repository (read-only) — the investigation is what it
tests, so **do not** turn it into a fictional scenario. Substitute `{PROTOTYPE_PATH}` in the
prompt with a path in your own workspace holding an older prototype whose functionality has
since been at least partly shipped elsewhere. Evals 1–3 are self-contained; tell the subagent
not to go looking for the paths on the machine.

Put the outputs in `<workspace>/iteration-N/eval-<id>-<name>/{with_skill,without_skill}/outputs/`.

## Note on eval 0

The prompt starts from a **deliberately false premise**: it asks to "promote the prototype to a
service" when the service already exists and ships. That is not a bug in the eval — it is the
most valuable test in the set, because it separates whoever investigates from whoever plans on
top of the prompt.

A planner that accepts the premise would send the fleet to rewrite thousands of lines that
already run. Keep the false premise in future iterations.

## What to watch when editing the skill

**The behaviour most likely to be lost is the final phase** (handoff comments): it is the last
step, and when the package grows the last step falls off. If you add content to the skill, check
that eval 2 still produces the comments file.

**The baseline is strong in this family of task.** Decomposing and writing acceptance criteria
is something a competent model does well on its own; roughly half the assertions pass in both
arms. The delta lives in the handoff machinery (the plan format, mandates, the sink, waves,
approval before the tracker) — if that shrinks after an edit, you probably diluted phases 4–6.

**Subagents inherit the user's own instruction files and memory**, so the baseline is not a naive
model. The delta measured here understates the skill's value in a project without that context.

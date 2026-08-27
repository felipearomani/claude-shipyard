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

## Read the firing indicator before you read the score

Every case's first assertion is a **plugin-fired indicator**, not a criterion. Report it
separately and never add it to the score. It answers a question the rest of the suite cannot:
*was the skill consulted at all?*

Skills are model-invoked, so this is not a given. Measured on the coordinator's
authorization-relay case, the skill fired in **7 of 11 runs** and the other four answered from
scratch and scored like the no-plugin baseline. Firing was bimodal — the skill's vocabulary was
either present or entirely absent, never partial — so a run that did not fire drags the mean
without looking like anything in particular.

That cost four rounds of edits to a skill body a third of the runs were not reading. The failures
looked like content defects: an assertion "regressing" between rounds, seven assertions reading as
"flaky". They were one binary variable upstream, measured as if it were nine independent ones.

So: if the indicator is absent in a run, that run says nothing about the guidance. Fix the
trigger — the `description` — before touching the body. The fix for the coordinator was six
quoted triggers for inbound agent messages; it moved firing from 7/11 to 12/12 (Fisher exact,
one-sided p = 0.037) and the score from 3.7/9 to 8.5/9, with no change to the body at all.

## Open: this skill's mid-flight phases have no measured trigger

Phases 4 to 6 — iterating the approval page, creating in the tracker, writing the handoff — are
reached today only by a session that entered the skill at phase 1. A plan is normally reviewed in
a different session from the one that produced it, so that path falls outside.

Measured on a prompt that is phase 4 in operation ("you planned MERC-500 yesterday, change two
things on the approval page before we create anything"):

    current description   0/5 fired   (no marker of any kind; identical to the no-plugin arm)
    + mid-flight triggers 2/5 fired   Fisher one-sided p = 0.22 — NOT significant

The diagnosis is solid: five runs, zero markers. **The fix is not.** The same class of patch moved
the coordinator from 7/11 to 12/12 (p = 0.037) with two independent markers per run; here the two
"fired" runs matched a single occurrence of one weak word — "falsifiable", which someone
discussing acceptance criteria may reach for unaided. Two readings survive, and picking one
without measuring is the mistake this suite exists to prevent:

1. the added triggers do not match this prompt shape;
2. they help, and the detector is too weak to see it.

Before treating this as solved: build a two-marker detector (as the coordinator has), raise n, and
re-run both arms. The triggers currently in the description are kept because the gap they address
is real, not because they were shown to close it.

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

**Grant the tools the case actually needs.** With no read grant the skill runs on its `SKILL.md`
body alone, and with no write grant it cannot produce the plan file — an assertion about what
`plan.md` contains can then only fail, which is a broken instrument rather than a finding. Grant
read and write into the output directory, and keep the same grant in both arms so the plugin
stays the only difference. Measured on this suite: granting read changed nothing, because both
skill bodies turned out to be self-sufficient for these cases — worth re-checking rather than
assuming, before anyone moves content out of a `SKILL.md` into `references/`.

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

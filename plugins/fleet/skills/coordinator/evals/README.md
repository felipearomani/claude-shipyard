# Evals for the coordinator skill

Five scenarios covering the whole cycle. Run them whenever you change `SKILL.md` or anything
under `references/` — this skill decides irreversible actions (merge, tag, deploy, killing a
process), so a silent regression here is expensive in production.

| # | Scenario | What it checks |
|---|---|---|
| 0 | `pre-dispatch-gate-and-lanes` | The expensive part: finding blockers BEFORE dispatch, sealing decisions, cutting lanes without domain collisions, creating the sink, producing prompts with a Definition of Done |
| 1 | `finding-outside-the-slice-and-authorization-relay` | The two rules that most often stall a fleet: a finding outside the slice goes to the sink, and an authorization relayed by the coordinator does NOT count |
| 2 | `clean-agent-shutdown` | Verify before accepting the report, preserve the session before the kill, verify the PID, check for children, post-kill hygiene |
| 3 | `monitoring-loop` | Reading the signals: late bookkeeping vs. a stall, idle as a sample, the CI queue as the real bottleneck, escalating rather than relaying |
| 4 | `model-and-effort-reassessment-at-dispatch` | The plan is a starting point: lowering a tier when the decision was sealed, raising when a destructive migration appeared, and carving that gesture out of the agent |

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

## How to run

Always in **DRY RUN**. The scenarios are fictional, but the skill instructs launching background
sessions, killing processes and writing to a tracker — in an eval that would start real processes
and write to a real board.

For each case, launch two subagents in the **same** round: one with the skill, one without
(baseline). Running the baseline afterwards biases the comparison.

The harness prompt needs to contain, literally:

```
DRY RUN MODE — absolute constraints:
- Do NOT launch or kill any process, and do not run the launcher detection against a live fleet.
- Send NO real messages. Write to NO tracker.
- Where the skill says to do those things, WRITE OUT the exact command or message you would run.
- Write files ONLY inside the output directory.
```

And, in the with-skill arm, point at the skill's `SKILL.md` and tell the agent to follow it,
including the reference files it asks for.

Put the outputs in `<workspace>/iteration-N/eval-<id>-<name>/{with_skill,without_skill}/outputs/`.

## How to score

The `assertions` for each case in `evals.json` are verifiable by reading the output — they need
no script. Count how many passed in each arm.

**The signal that matters is not the absolute score**, it is the *delta* against the baseline. A
competent model without the skill gets much of case 0 right (cutting lanes is intuitive) and gets
almost all of case 1 wrong (the authorization relay is counter-intuitive: the instinct is to be
helpful and pass along the human's "yes"). If case 1's delta shrinks after an edit, you probably
weakened the authorizations section.

## Trap when editing the skill

When adding something new, check that case 0 still **runs the gate with the human before
launching**. It is the easiest behaviour to lose: the more detailed the rest of the skill gets,
the more the model tends to execute directly and show the plan afterwards.

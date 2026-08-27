# Evidence rules

These rules come from a real night of work with three autonomous agents. They
caught **nine false claims**, several already in production code, and most were
committed by the very people writing the rules down — including the coordinator.
That is not carelessness. It is the natural way a fast, confident agent is wrong.

They are written with the cases that produced them, because a rule without its
case degrades into a slogan, and people ignore slogans exactly when they matter.

They go embedded in every agent's prompt. The coordinator applies them to itself
with **more** rigor, because a coordinator's claim carries more weight than an
agent's, so being wrong as coordinator costs more.

---

## 1. Label every claim: MEASURED / DERIVED / ASSUMED

- **MEASURED** — you executed it. Cite the command, the mutant, the outcome.
- **DERIVED** — you read the code. Cite what you read.
- **ASSUMED** — neither of the above.

All three are acceptable. What is not acceptable is one passing for another:
**with no label, the reader assumes the strongest one.**

**Severity scales with reach:** a doc vendored across several repos > a PR
description > a code comment > a ticket comment. The further a claim travels, the
more people build on it without being able to check it.

*Case:* an agent swept the six "MEASURED" claims in its own slice and found one
false — in a doc vendored across three repositories, claiming MEASURED what had
been derived by reading. Nobody had ever executed the scenario.

*Case (coordinator):* a coordinator claimed from memory that a spec decision had
been implemented a certain way, labelled it DERIVED, and still became the
**third concurring source** for a wrong conclusion. **A label does not neutralize
authority** — whoever coordinates has to be more conservative, not equally
conservative.

## 2. Every absence needs a positive control

"I did not find X" only becomes "there is no X" if the **same probe** finds a
target you know exists. Without that, absence and broken instrument are
indistinguishable — and both look like success.

*Cases, all the same night:*
- `aws-vault list | head -5` → "the profile does not exist". It did; `head` cut it.
- `aws-vault list | head -10` → same conclusion, **twice**, same profile.
- grep for a literal message-subject string → only matched a comment. Replaced by
  enumerating actual subscriptions, and the real thing showed up.
- `grep -c` over a log → zero. But the pods were 12 hours old and the event was
  from July: the absence was the **window**, not the fact.

**The corollary that cost the most:** the positive control has to belong to the
probe that produced the conclusion, **not to a neighbouring probe**. An agent
controlled its `.pgpass` parser and then concluded from a truncated credential
listing. A control in the wrong place is worse than none: it manufactures a
feeling of rigor.

## 3. Reviewers disagree ⇒ MEASURE, never pick a side

When two adversarial reviews diverge, the point of divergence almost always hides
a real defect. Do not decide by eloquence or by majority.

**It is not the most confident reviewer who is wrong — it is the one who did not
execute.** Confidence correlates with error only because people who do not run
things tend to sound more certain.

*Case:* reviewer A confirmed that a compliance vector locked a required field;
reviewer B denied it. B was right — the payload crossed as an opaque raw JSON
value and the codec was never invoked. With a single review, the slice would have
shipped with the defect.

*Case:* reviewer A cleared a clamp "with proof executed on four flanks"; reviewer
B rejected it. A had answered the wrong question — it proved the detector matched
the *clamp*, not the *damage*.

## 4. The instrument must be able to go red

Operational requirement: **remove the mechanism; the test has to go red.**

The formulation that best describes the whole family:

> It is not "the test was missing" — the test **existed, ran and passed**, and
> would have passed identically with the entire mechanism removed.

*Cases:*
- a savepoint test that never exercised the savepoint;
- a count-based ratchet that climbed on its own;
- a probe reading a column named `uncollectible_em` when the column is
  `uncollectible_at`, without checking the scan error — it returned the
  **opposite** of the truth, and nearly settled a disagreement between reviewers
  with a number in hand;
- an audit test passing a malformed uuid, killed in the cast before it ever
  reached the code it claimed to test;
- ~290 lines of proof **CI never ran** — they did not even compile;
- a vendored contract with no consumer at all: conformance confirmed itself, and
  the contract drifted for three cycles with nobody noticing.

**"I measured" carries the same rhetorical weight as "I reviewed", and evaporates
the same way when the instrument could not fail.**

## 5. A gate that passed is not a gate passing

Green hours ago is not green now. Re-run the gate **immediately before** merging
or tagging.

*Case:* a migration-collision gate passed green in the morning; by the afternoon
the base branch already carried the same number, from another agent. Four
collisions in one night; that was the only one that nearly escaped through
**elapsed time** rather than carelessness.

**Corollary on rebase:** a rebase is a *proxy* for two invariants — no migration
number collision, no file overlap. A direct and **named** verification of those
two replaces the rebase when the base branch moves too fast to converge on. The
part that does not loosen is "named": saying "I checked" without saying what is
ASSUMED wearing the face of MEASURED.

## 5b. Verify the EVENT, not your reproduction of it

Reproducing a failure locally proves the mechanism **exists**. It does not prove
that mechanism **acted** in the case you are fixing.

This is the most expensive species in the catalogue, because the others produce a
weak test and this one produces **the entire slice at the wrong layer** — correct
in itself, solving a problem nobody had, merging green. No test gate catches it:
the tests for the fix all pass.

*Case:* a product's download page was stuck on an old version. The coordinator
ran the generator locally, saw a guard refuse because an artifact was missing, and
concluded the guard was the cause. The agent built the fix on that, and both
reviewed the plan twice from the same premise.

Measured afterwards: the job that runs the generator **never executed** — it was
skipped because an earlier job failed. The guard existed and did refuse, but it
had never acted. Worse: the proposed fix (tolerate a missing artifact) would only
ever run in the scenario where the artifact **is** present, because of the job
dependency chain. A tolerance unreachable by the failure mode it claimed to serve.

**The remedy costs one command:** open the run, the log, the record of the event —
before writing the justification. Inspect the actual run before forty lines of
analysis.

## 6. Corroboration between artifacts of intent is not corroboration

A spec, a code comment, a ticket and a product manager's memory all describe what
someone **intended**. Their agreeing with each other proves nothing about what the
code **does** — they share a single origin.

Only the **code** and its **execution** are second-order sources.

*Case:* the spec said "remove the write from the point-of-sale" and the comment in
the file said "the POS only reads". Two concurring sources, wrong conclusion: the
POS emitted an operation to the arbiter (which is the correct model), and the line
in question was written by the cloud. Both statements were true at the same time,
about different things.

## 7. Put a date and a reach on every measurement

A measurement without a date promotes itself from "what we saw once" to "what is
true".

Write: *"snapshot of {date}, which sized the DESIGN and does not authorize
execution"*. And declare the limit: what the measurement does **not** reach (repo
not swept, subject coming from runtime config, log window).

## 8. Scope of the measurement = reach of the conclusion

Measure at the scope of the **conclusion**, not at the scope of the doubt.

*Case:* the doubt was "does the console use this route?" and the grep covered only
the frontend. But the conclusion — tightening the route to owner-only — would
break **any** client. Redone across all three repos.

## 9. Do not re-run CI until it passes

If a test fails reproducibly, that is a finding — open a ticket. **Re-running
until green is the most expensive way to hide a bad test.**

*Case:* a percentile test with a *relative* threshold (20× a baseline measured in
the same contended run) was failing PRs that never touched it. Proven by
bisection: the failure appeared on a commit that changed **zero** non-comment
lines. The defect is not the slowness — it is the threshold being relative to a
baseline measured under contention.

## 10. Admitting a gap has to cost zero

Any quality gate you build needs this property: **if admitting a gap costs more
than claiming coverage, the gate produces more false claims, not fewer.**

*Case:* the first version of a cite-your-test gate made its author **delete three
historical names** rather than declare an exception — because deleting was
cheaper. Rebuilt with an inline admission marker.

---

## When a gate keeps leaking, the problem may be the class of the claim

The most advanced piece here, and it generalizes to gate design:

Proving a **positive** claim ("every read filters by `deleted_at`") about SQL
requires understanding the structure of the SQL — and a text scanner does not.
Each fix moves the hole: it escapes through a qualified schema, a comma join, a
name assembled by string formatting, a CTE, an embedded file; and it produces
false **red** on a full outer join, which is worse, because that teaches the next
person to silence the gate.

The way out was not more cases in the regex. It was **changing the type of
guarantee**: a view that cannot see the revoked row turns the problem into a
**negative** claim about a token ("outside of writes, the base table never appears
in SQL") — and a scanner can sustain that one, because every evasion contains the
token.

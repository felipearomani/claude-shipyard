# Fleet failure-pattern catalogue

Consult this at the pre-dispatch gate (to warn the agents up front) and whenever
an agent reports something strange (to recognize the pattern instead of
investigating from scratch).

Everything below was observed in real fleet runs. The specific tools named in the
cases — a particular migration runner, credential helper, CI setup — are the
tools where it happened, not a claim about your project. Read the shape, then ask
whether your stack has the same shape.

---

## Coordination

### Rabbit-hole through review findings

**Symptom:** the epic gains tasks faster than it closes them. Every adversarial
review produces findings, every finding becomes a task in the same epic, and the
definition of done implicitly becomes "every finding from every review closed" —
infinite by construction.

**Real numbers:** one epic gained ~20 tasks in a single night. Classified by
evidence, only 4 of 21 open tasks belonged to the original promise.

**Cure:** a **sink** epic/label created **before** dispatch, with the rule in the
prompt: a finding that is not a regression of the agent's own slice goes to the
sink. When moving in bulk, leave a trail comment in **both** epics — what left and
why, what arrived and where from.

### Umbrella task that does not close with the first slice

**Symptom:** a task like "extend X to the remaining entities" hangs around and the
epic never closes.

**The distinction that resolves it:** an umbrella of **expansion** (beyond what the
epic promised) goes to the sink. A **prerequisite of the promise** stays in the
epic — moving it would be closing by name rather than by content.

Rewriting the acceptance criterion to match what was delivered **is not a trim, it
is a different task.** Say that when someone proposes it.

### Authorization relay

**Symptom:** you pass along "the human authorized it" and the agent refuses,
correctly. The lane stalls for hours.

**Cure:** mandates in the launch prompt (an originating mandate, not a relay). If
one is missing after dispatch, the human answers **in the agent's own session** —
ask for that in one line and do not push further.

### Late bookkeeping looks like a stall

**Symptom:** zero tasks "In Progress" with dozens open.

**Diagnosis:** list the running agents. A shell/working state means executing; idle
means waiting. Only investigate a stall when the agent is idle with a non-empty
queue.

### Orphan issue

**Symptom:** tasks created by an agent do not show up in your board query.

**Cause:** created without a parent. It happened to eight at once.

**Cure:** a rule in the prompt — after creating, **read the issue back** and confirm
the parent. Creating is not the same as creating correctly.

---

## CI / delivery

### Migration number collision

**Symptom:** two branches with the same number. The migration runner refuses the
whole directory and the service does not boot. Nobody notices until production
startup.

**Real frequency:** four in one night.

**Cure:** verify **immediately before** the merge/tag, not at push time. The fourth
one nearly escaped because the gate had passed green hours earlier, when the base
branch did not yet carry the number.

**Design note:** turning on "require branches to be up to date" forces a rebase and
brings the treadmill back. The right gate probably compares the branch's migration
numbers against the base's, rather than requiring the branch to be current.

### Stacked PR meets squash merge

**Symptom:** the base PR merges, and the branch stacked on it now conflicts with content it
already contains. The platform does not auto-retarget, because the merge queue leaves the base
branch in place.

**Cause:** squash rewrites the base's commits, so the stacked branch's ancestry no longer shares
them.

**The dangerous part:** resolving it by merge reintroduces whatever the base deliberately
removed, and nothing flags it. One case brought back a TTL a prior PR had removed on purpose,
buried in 16 conflicts.

**Cure:** `git rebase --onto <new-base> <old-tip-SHA-of-the-base>` — the **SHA**, not the branch
name, because the branch has moved. Record that SHA at dispatch, while it is still easy to get.
And prefer independent lanes over stacked ones in the first place.

### Runner queue serializing everything

**Symptom:** finished PRs sitting for tens of minutes; looks like a stalled agent.

**Cause:** a shared runner pool without cancel-in-progress; one hungry job blocks
the queue. Observed: 90 minutes.

**Cure:** cancelling runs for superseded commits unblocks it. For the chronic case,
enable cancel-in-progress on PR branches.

### Latency test with a relative threshold

**Symptom:** a test fails PRs that never touch it, intermittently.

**Diagnosis:** bisection. If the failure appears on a commit that changed zero
non-comment lines, it is not the diff.

**Root cause:** a threshold relative to a baseline measured in the **same** contended
run. Under a full queue, the baseline and the p99 degrade together, differently.

**Vicious circle:** contention → failure → re-run → more contention.

### A test CI never reached

**Symptom:** an entire package of proofs that never ran — sometimes they do not even
compile.

**Cure:** the pattern repeats, so it is worth sweeping for **which packages contain
tests no CI step reaches**. That is a blind instrument at repository scale.

### Orphan test containers

**Symptom:** unexplained integration failures, containers piling up.

**Cause:** the reaper does not collect when the test process dies from a signal.

**Cure:** sweep by label at the end of every batch — and **always before believing an
integration failure you cannot explain**.

### Lockfile pruned on one platform

**Symptom:** the build breaks in CI and passes locally.

**Cause:** installing dependencies on a developer machine strips optional packages
for other platforms out of the lockfile.

---

## Architecture / code

### A live surface the documentation denies (and the reverse)

Three shapes of the same defect, all in one night:

- **a vendored contract with no consumer** — conformance confirms itself;
- **a live permission for a dead path** — the ACL grants a channel nobody
  subscribes to, and the comment promises an adapter that does not exist;
- **a live write under a policy that forbids it** — either the comment is wrong, or
  the fence was never raised.

The axis: **what the code does and what the repository says have diverged, and it is
the saying that is being read.** An *authorization* surface with no consumer is the
worst of the three — someone finds it later and uses it as proof that the path
exists.

### A zero that is zero by construction

**Symptom:** an acceptance criterion like "the enforcement rejected N invalid
operations" comes back zero, and someone reads zero as approval.

**Diagnosis:** the zero comes from the absence of an **emitter**, not from the health
of the fence.

**Cure:** an acceptance criterion that measures what exists (the lease covers 100% of
live shifts; the residue is zero counting the terminal state) and states in writing
what is **not** yet measurable, with the exact unblocking condition.

### Terminal rejection in an act involving money

**Symptom:** a gate definitively rejects an operation that represents physical
movement of money.

**Rule:** money that left the drawer does not become a terminal rejection — it goes to
a human adjudication queue. Being auditable does not make it acceptable; it makes it
investigable later.

**Neighbouring trap:** when routing to a queue, verify the operation **can leave** the
queue. One case: applying it re-projected, the same gate fired again, and the
operation returned to the queue — permanently, because the predicate was monotonic.
The only way out was discarding it.

### A machine message on an operator's screen

**Symptom:** a snake_case identifier or a contract term showing up for whoever
operates the system.

**Cure:** three classes, not two — *has a phrase* (show the phrase), *known without a
phrase* (a copy gap, show the term spaced out), *unknown* (version skew, "update the
app"). Merging the last two erases the only signal that requires user action.

### The gate that measures the adjacent thing

The most common pattern of all. Observed examples:

- a contract golden that compares the **shape**, not the **source**;
- a contract script that measures **internal** consistency, not synchrony between
  repos;
- a linter run over the **touched files** when the gate measures the **repo against a
  baseline**;
- an ACL test that proves the permission **exists**, not that it was **exercised**.

When designing a gate, ask: *which exact claim does it sustain?* And then: *is that
the claim I need?*

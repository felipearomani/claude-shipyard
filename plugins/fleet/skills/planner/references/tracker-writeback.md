# Creating the tasks in the tracker

Only after the human approves. Bulk creation is the moment a small mistake becomes a large
cleanup job.

## Rules that hold in any tracker

**Confirm the link by reading it back after creating.** Creating is not the same as creating
correctly. One batch of eight issues was born with no parent and stayed invisible to every query
the coordinator ran — the work existed, nobody saw it, and it only surfaced when somebody
questioned the number. After creating, **read the issue back** and check the link field. Do not
trust the create response.

**Create in dependency order** and record the keys as they come out. You will need them to write
"B depends on A" — and if you create everything first and link afterwards, one will end up
unlinked.

**Create the sink epic/label alongside**, before any task of the round. It is where the review
findings will land. And **define the owner**: who drains it, when, and under what priority. A sink
with no owner is a backlog that only grows, and you will report it at every tick without anything
happening.

**Sign what is yours.** The acceptance criterion you wrote carries a note that it was written
during planning, with a date, open to veto. That lets somebody challenge it later without feeling
they are defying the spec.

**Do not paste secrets or customer data.** Not even from staging. If the task needs a credential,
describe **what it unblocks**, not its value. A board is usually more open than the data.

**Security findings:** a descriptive title in the ticket, technical detail over a private channel
to the human. Describing the exploitation path in a visible issue is publishing the vulnerability.

## Before creating in bulk

A cheap check that avoids rework: **create ONE task first**, read it back, confirm the parent, the
required fields and the formatting came out as you expected. Only then create the rest.
Discovering at item 20 that the type field was wrong means editing 20.

## Per tracker

### Jira

- The link to the epic is the `parent` field (in team-managed projects) — that is the one that
  fails silently. Check it by reading the issue back after creating.
- Always refer to keys as **"KEY — title"**, never the bare key: whoever reads the comment months
  later does not memorize numbers.
- A trail comment in both directions when moving something between epics: at the origin saying
  what left and why, at the destination saying where it came from.
- Descriptions use a rich-text document format; if the tooling accepts markdown, check the
  rendered result — tables and code blocks are what break most often.

### GitHub Projects / Issues

- An issue and a project item are different things: creating the issue does not put it on the
  board. Confirm it appeared in the project and in the right status field.
- Dependencies are not native; use a reference in the body (`depends on #NN`) and record the order
  in `plan.md`, which is where the coordinator will look.
- A label is the cheap substitute for an epic. If you use a label as the sink, create it first — a
  non-existent label fails silently in some API paths.
- Some CLI subcommands speak GraphQL and that returns 503 with some regularity; the plain REST
  issues endpoint is more stable for bulk creation.

### Asana

- A subtask and a task with a parent are different mechanisms; pick one and be consistent, or half
  the work disappears from the project view.
- Required custom fields reject the whole creation — discover which ones with the first task, not
  with the twentieth.

### Linear

- The cycle is assigned by default and can throw the task into a sprint you did not intend. Check
  after creating.
- Dependency relations are first-class here; use them instead of text.

## After creating

Go back to `plan.md` and **fill in the real keys** — the plan you wrote earlier has placeholders.
The coordinator will use those keys to query the board at every tick; a placeholder there means a
wasted tick.

And leave the handoff comment on each task: the lane it belongs to, its dependency, and the path to
the plan. The disk is local and disappears; the comment stays on the ticket and is what somebody
finds three months from now asking why that task exists.

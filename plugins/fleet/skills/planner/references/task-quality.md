# Task quality for an autonomous agent

A good task for a person and a good task for an autonomous agent are not the same thing.
The person asks when they get stuck; the agent decides. Everything you leave ambiguous
becomes a decision made without you, unrecorded, and discovered at merge.

## The acceptance-criterion test

**Can you imagine the command that proves the criterion?** If not, it is not ready.

A good criterion is **falsifiable**: there exists a state of the world in which it clearly
fails. "The contract is in sync" has no such state — you can always argue that it is. "Editing
one of the four vendored files without the others makes CI fail" does: you edit one, and either
it fails or it does not.

| Bad | Why it fails | Good |
|---|---|---|
| "the contract is in sync" | there is no way for it to be false | "editing 1 of the 4 vendored files without the others → CI red" |
| "adequate error handling" | "adequate" belongs to the reader | "an operation with a non-existent approver → `rejected(invalid_approver)`, and the audit row is written EVEN on the refusal" |
| "the screen works well" | names no state | "a table in `paying` renders the 3rd visual state; the test fails if it falls back to `occupied`" |
| "test coverage" | measures quantity, not a property | "removing the guard makes the test go red" |
| "acceptable performance" | implicit threshold | "p99 < 300ms with 10 concurrent locations, measured against a fixed baseline — not relative to its own run" |

## The three fields that save hours

Besides the criterion, include when you know them:

**The file:line where it lands.** The agent will find it anyway, but it burns context — and
sometimes it finds the wrong place and fixes the similar-looking thing.

**The precedent to follow.** "Follow the pattern in `orders/table-api.ts`" is worth more than
three paragraphs describing the pattern. And it stops the agent from inventing a second way to
do the same thing, which is how a repository rots.

**The known trap.** This is the line with the highest return per character in the whole ticket.
Real examples: "the migration collides if another branch merges first — check the number
immediately before the merge, not at push"; "installing dependencies on macOS prunes optional
packages and breaks the Linux CI"; "this package has a latency test with a relative threshold
that fails under runner contention".

## The degenerate states

An agent does not ask "what if it comes back empty?". It picks — and each lane picks
differently. Name explicitly what happens with:

- an empty collection, and a collection with exactly one item
- a record with no children (a sale with no items, a tab with no payments)
- zero, negative, null
- an entity with no permission / a user with no role
- the operation repeated (idempotency)
- the network dropping midway, the process dying midway
- **the data changed between the read and the write** — a price that went up after the item was
  added to the cart, an item discontinued since the snapshot, a schema version newer than the
  binary, a config exported from another machine. Do not confuse this with *where the data
  lives*: deciding that the price is not persisted in the cart answers where it lives and does
  **not** answer what the user sees when it changes. If a sealed decision removes a field, it
  has to say what happens to the case that field covered — otherwise the case does not leave the
  stage, it only leaves the paper.

If the spec does not cover them, either you define them now, or they become divergence between
lanes.

## Enriching a thin ticket without rewriting it

When the board already exists and the tickets are vague, you are editing somebody else's work.
Two rules:

**Preserve what is written.** The original text may hold context you do not have — who asked for
it, why, what was already tried. Add sections; do not replace the body.

**Mark what is yours.** A section titled "Acceptance criteria (written during planning on {date},
open to veto)" makes clear what was decided later and by whom. An acceptance criterion that
appears with no authorship becomes law with no legislator, and nobody feels free to challenge it
even when it is wrong.

And if while enriching you discover the task should not exist — because it is already done,
because it duplicates another, or because the problem changed — say that to the human instead of
writing acceptance criteria for useless work.

## How many tasks

Prefer **fewer, well-defined tasks** to a board full of drafts. A draft on the board of an
autonomous fleet is not neutral: an agent will pick it up and turn the ambiguity into an
arbitrary decision, and you will end up reviewing the result of that instead of reviewing the
decision.

A size that works: one task = one PR. If you cannot picture the PR, it is too big; if it is three
lines in three files, it probably belongs with another.

## Dependency is first-class information

Say it explicitly: **B depends on A** (same lane, serial), or **B and C are parallel but touch
the same file** (boundary by glob, owner declared), or **D depends on nobody** (can go to any
lane).

An undeclared dependency is what makes two lanes arrive at the same file at the same time — and
the cost shows up at the rebase, when both are already finished.

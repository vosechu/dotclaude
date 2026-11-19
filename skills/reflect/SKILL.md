---
name: reflect
description: Reflect on the conversation and route any durable knowledge to the correct storage surface. Default is discard. Memory is nearly always wrong.
---

Invoke at the end of a productive session where you learned something non-obvious about the project, the user, or the workflow — or when the user asks you to reflect. Skip if the session was routine (bug fix with no surprises, simple file edits).

Reflect on the session and decide where — if anywhere — each learning goes. Most sessions produce no artifacts. Noise in permanent files is worse than forgetting.

## The decision tree

For each candidate fact, apply these questions **in order** and stop at the first match:

1. **Is it already derivable from code, git log, an existing rule, or CLAUDE.md?** → **DISCARD.** Never paraphrase what `grep` or `git log` answers faster.
2. **Is it one-time specifics** (today's task, current bug state, counts, dates, "we just did X")? → **DISCARD.**
3. **Would the fact be wrong to commit to the shared repo?** — personal to *you* working on this project, not about the project itself → **memory** (see §Memory below; the gate is tight).
4. **Is it relevant to ~90%+ of future sessions on this repo?** (cross-cutting anchor principle, project identity, directory map index) → **CLAUDE.md**.
5. **Does it always apply when editing specific files?** (mechanical trigger — a file-path predicate covers every case) → **path-gated rule file** (`.claude/rules/<topic>.md`).
6. **Does it apply when doing a specific kind of task?** (semantic trigger — spans paths, or only applies to some edits in a path) → **skill** (tag/description-gated, progressive disclosure).
7. **Is it dense specialist content that would bloat even a rule if always path-loaded?** → **skill** (size override wins).
8. **Otherwise** → **DISCARD.**

### File or goal? (the rule-vs-skill sharpener)

The ambiguous cases between 5 and 6 resolve on one question: **is the trigger a file or a goal?**

- **File trigger** → path-gated rule. Deterministic. Predictable. Zero reasoning overhead. Wins when the rule applies to *every* edit of those files.
- **Goal trigger** → skill. Semantic. Agent decides to invoke from the one-line description (cheap, always in context). Wins when the rule applies to a task shape that cuts across paths, or to only some edits in a path.

Examples:
- *"TypeScript vars use explicit return types on exported functions"* — every `.ts` edit → path-gated rule.
- *"How to add a new database migration"* — task shape spanning schema/model/test paths → skill.
- *"Release checklist"* — applies when *cutting a release*, not every edit → skill.
- *"API handlers return a typed Response envelope"* — every handler edit → path-gated rule.
- *"Triage a chaotic git state"* — intent-based, spans the whole repo → skill.

When both apply: do both. Split the subsystem into:

- A **path-gated rule** that carries the always-true content — shapes, invariants, schemas, reference tables. Loads on every matching edit. Should stay compact.
- One or more **goal-gated skills** for dense specialist procedures or task shapes.
- **Link from the rule to the skills** with explicit pointers: `→ invoke /add-migration when …`. This makes skill discovery mechanical rather than relying on the agent to match a one-line description.

This is the same indexing pattern CLAUDE.md uses to point at rule files, applied one level deeper: rules index skills.

A thin reflection — zero new artifacts — is a good reflection.

## The four surfaces, ranked by load cost

Storage choice is a **context-cost** decision. Pick the cheapest surface that still loads the fact when it matters.

### CLAUDE.md — loaded every session

- Cost: tokens spent on **every** turn, forever.
- Use for: the 90%+ rules. Project identity, top-level conventions, anchor principles, the table of contents pointing to rule files.
- Keep under ~200 lines. If a topic grows past 30 lines, move it to a rule and link.
- **Red flag:** if you're adding something here that only applies to one subsystem, you're overpaying. Move it to a rule.

### Rule files (`.claude/rules/*.md`) — path-gated, auto-loaded on file match

- **Trigger:** mechanical. A glob pattern on the rule (or a CLAUDE.md import) loads the full file whenever the agent edits a matching path.
- **Cost:** tokens spent **every time** the agent touches matching files, whether or not the task actually needs the rule.
- **Reliability:** 100%. The agent cannot miss a path match.
- **Use for:** conventions that apply to *every* edit in the matching path — code style, naming, schemas, file-shape invariants.
- **Red flags:**
  - Rule is over ~300 lines and most tasks in the path don't need all of it → split the dense specialist part into a skill.
  - Rule only applies to *some* edits in the path → it's a goal-triggered concern; make it a skill.

### Skills — tag/description-gated, loaded on invocation (progressive disclosure)

**Skills are lazy-loaded context, not recipes.** The test is "when should this be in the agent's head?", not "is this a repeatable process?"

- **Trigger:** semantic. The skill's one-line `description` is always visible in the skill list (cheap); the body loads only when the user types `/name` or the agent reasons that the description matches the current task.
- **Cost:** description always in context (cheap); body cost **zero** until invoked.
- **Reliability:** depends on description quality and agent attention. A weak description = missed invocations. Write descriptions that specify intent triggers explicitly ("use when …").
- **Use for:**
  - Task-shape triggers that cut across paths (adding a migration, cutting a release, triaging git state, reviewing a PR).
  - Dense specialist context that would overpay as a path-gated rule.
  - Multi-step procedures with enough gotchas to need their own doc.
  - Context a teammate rarely needs but that is vital when they do.
- Skills live in `.claude/skills/<name>/SKILL.md` (project) or `~/.claude/skills/<name>/SKILL.md` (user).
- **Red flags:**
  - Skill fits in 40 lines and applies on every matching edit → demote to a path-gated rule; the lazy-load saves nothing.
  - Description is vague ("use when working on the system") → agent will miss it. Rewrite with concrete intent verbs.

### Memory — private, per-project notebook

- Cost: the `MEMORY.md` index loads every session; individual entries load when referenced.
- **Default: do not write here.** Most things that look like memory candidates are really rules in disguise or one-time specifics.
- **Write memory only if all of these are true:**
  1. The fact is about **you working on this project**, not about the project itself.
  2. A teammate opening this repo would find the fact irrelevant or weird.
  3. You'd make a *different decision* in a future session without it.
  4. It is not a point-in-time measurement that a command could answer fresh (coverage %, build status, error counts). "Where we left off" and next-step intent are fine — stale metrics are not.
- If any one fails → do not write.
- Workflow preferences *might* qualify, but most preferences that feel memory-shaped are actually team conventions and belong in rules where teammates will see them too.
- When in doubt: don't write memory. Offer to add a rule instead.

## Worked examples

| Fact | Where | Trigger | Why |
|---|---|---|---|
| "TypeScript exported functions have explicit return types" | path-gated rule (`code-style.md`) | file: `*.ts` | Every TS edit needs this. |
| "API handlers return `Response<T>` envelope" | path-gated rule | file: `src/handlers/*.ts` | Mechanical trigger; never missed. |
| "All services must emit OpenTelemetry spans" | CLAUDE.md | always | Cross-cutting; every session. |
| "Full release-cut checklist (branch, changelog, tag, deploy)" | skill | goal: cutting a release | Dense procedure; only applies at release time. |
| "How to add a new database migration" | skill | goal: schema change | Task shape spans schema/model/seed/test paths. |
| "Auth uses JWT with 15-min access + 7-day refresh" | path-gated rule (`auth.md`) | file: `src/auth/*` + middleware | Subsystem reference; applies to all work in the path. |
| "Triage a chaotic git state" | skill | goal: inspecting unknown repo state | Intent-based; spans the whole repo. |
| "Run `npm test && npm run lint` before claiming done" | skill (`verification-before-completion`) | goal: claiming done | Task shape, not a file. |
| "Bug tracker is Jira project ACME" | CLAUDE.md (References) | always | Team-shared, discoverable, tiny. |
| "I prefer terse responses" | memory (only if not in global user prefs) | n/a | About the person, not the project. |
| "Feature X shipped on branch Y unmerged today" | DISCARD | — | State snapshot, rots. |
| "We upgraded Node to 20.11 on 2026-04-19" | DISCARD | — | One-time specific. |
| "Tests live in `tests/` mirroring `src/`" | DISCARD | — | One `ls` reveals it. |

## Updating vs adding

If a candidate resembles an existing entry *anywhere*, **update the existing entry** instead of creating a sibling. Duplicates rot.

If an existing memory or rule is now wrong or stale, **delete or correct it** — removing rot is higher-value than adding new facts.

## Report format

End with a three-line summary:

- **Kept:** `<path>` — one sentence why.
- **Rejected:** `<what>` — which gate failed (usually derivable, one-time, or failed memory gate).
- **Corrections:** `<path>` — what existing entries were removed or fixed.

If the session changed how you'd approach future work in this repo, that's worth capturing — don't discard it just to keep the count low.

## Verbosity

When you do write an artifact, keep it tight. Rules and memory entries should be the minimum text needed to change behavior — not explanations, not justifications, not examples unless the rule is ambiguous without one. A three-line rule that fires correctly is better than a thirty-line rule that's more "complete." LLMs tend to over-generate; fight that instinct here.

Begin the reflection now.

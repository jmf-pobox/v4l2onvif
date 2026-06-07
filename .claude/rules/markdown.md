# Markdown Hygiene

## Lint

- All `.md` files must pass `markdownlint` (part of `make check`).
- Blank lines around lists, fences, and headings.
- Fenced code blocks must have a language specifier (`cpp`, `bash`,
  `cmake`, `text`, `yaml`, `xml`).
- Ordered lists use `1.` prefix (markdownlint MD029).
- Line length: no hard limit, prefer wrapping prose at ~72 chars.

## Structure

- One `# Title` per file (H1). Sections use `##`, subsections `###`.
- Tables: use pipes, align header separators.
- No HTML unless markdown can't express it.
- No trailing whitespace.

## Docs Directory

| Path | Content |
|------|---------|
| `docs/BUILDING.md` | Build, toolchain, quality gates |
| `docs/TESTING.md` | 4-layer testing strategy, fixtures, CI matrix |
| `docs/GIT.md` | Branching, PRs, review, merge, cleanup |
| `docs/WORKFLOW.md` | Development lifecycle, phases, DoD gates |
| `docs/DESIGN.md` | ADRs for non-trivial decisions |
| `docs/ARCHITECTURE.md` | Current layering, threading, gSOAP model |
| `docs/PATCHES.md` | Fork deltas from upstream, with rationale |

## ADR Naming

Inline in `docs/DESIGN.md`, sequentially numbered: `ADR-001`, `ADR-002`,
etc. Each ADR includes: Date, Status, Context, Decision, Alternatives,
Consequences, Tests.

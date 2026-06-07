# Development Workflow

Every code change follows this pipeline. Steps are ordered — do not
skip ahead.

## Phase 1: Frame the Change

State the change as a sentence: *"<what> changes from <before> to
<after> so that <observable behavior>"*. If you can't finish that
sentence, you don't have a change yet.

## Phase 2: Branch

Create a feature branch from master. See `docs/GIT.md` for branch
prefixes. **master has branch protection — never commit directly.**

```bash
git checkout -b <prefix>/short-description master
```

## Phase 3: Write the Failing Test First

For bug fixes: write the test that reproduces the bug, watch it fail,
*then* write the fix.

For features: write the test that pins the new contract, watch it
fail, *then* implement.

For changes to gSOAP-generated paths: capture the wire format with
`tcpdump` first, commit the capture as a fixture, then write the test
that asserts the parser/serializer matches the fixture.

If a change passes review without a test, it's incomplete.

## Phase 4: Implement

1. Pure functions first. Side-effecting code wraps them.
2. Read the upstream code before deviating from it.
3. Modern C++20 in new code. Modernize touched legacy functions.
4. One concept per commit.

## Phase 5: Quality Gates

Run gates after each logical commit:

```bash
make check
```

Zero warnings, zero errors. If a gate fails, fix or revert before
the next commit.

## Phase 6: Definition of Done

Every change must pass ALL gates in order. Do not open a PR until
gate 6 passes.

### Gate 1: Code complete

The change solves the actual problem, not a subset. Partial fixes
with visible artifacts are work in progress, not code-complete.

### Gate 2: Tests added

Every behavior change has a test that fails on the pre-change code
and passes on the post-change code. No exceptions.

### Gate 3: Quality gates pass

`make check` is green: format, tidy, cppcheck, markdownlint, ctest
debug, ctest asan. Zero warnings, zero errors.

### Gate 4: Code review (local)

Run the code-review agent (or peer review) on the diff. Address
every valid finding. Repeat until clean.

### Gate 5: Documentation

- ADR in `docs/DESIGN.md` for non-trivial design decisions
- Update `docs/PATCHES.md` if this is a deviation from upstream
- Update `README.md` if user-visible behavior changed

### Gate 6: Manual smoke (optional, when warranted)

For changes touching the Discovery → Profile → StreamUri path, run
the Win11 checklist from `docs/TESTING.md` Layer 4. This is a smoke
check, not a substitute for L1–L3 tests.

### Gate 7: PR

Only now. See `docs/GIT.md`.

## What Goes Wrong When You Skip Phases

The session from 2026-06-06/07 skipped Phase 3 (test first) on every
patch. Every patch then needed two iterations because we discovered
the bug had a sibling we hadn't seen. The siblings were obvious in
hindsight — they were one assertion away.

The cost of writing the test first is 10 minutes. The cost of finding
the second bug by Win11 round-trip is an hour.

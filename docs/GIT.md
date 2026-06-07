# Git Workflow

This document covers branching, commits, PRs, review, merge, and
cleanup for this fork.

## Branch Discipline

Feature work goes on feature branches created from master:

```bash
git checkout -b <prefix>/short-description master
```

| Prefix | Use |
|--------|-----|
| `feat/` | New features, new SOAP methods, new test layers |
| `fix/` | Bug fixes (must include regression test) |
| `refactor/` | Restructuring, modernization (no behavior change) |
| `test/` | Test additions only |
| `docs/` | Documentation only |
| `build/` | CMake, CI, dependency, toolchain changes |
| `chore/` | Tooling, dotfiles |

**Never `git rebase` or `git push --force` on a branch with an open
PR.** Force-push rewrites commit SHAs, which orphans every reviewer's
in-flight comments. Resolve base conflicts via merge.

## Commit Messages

Format: `type(scope): description`

| Prefix | Use |
|--------|-----|
| `feat:` | New feature or capability |
| `fix:` | Bug fix (body must reference the failing test that catches it) |
| `refactor:` | Modernization, no behavior change |
| `test:` | Adding or updating tests |
| `build:` | CMake, CI, dependency changes |
| `docs:` | Documentation |

Examples (the patches from this session, recast as commits with tests):

```text
fix(serverMedia): map V4L2_PIX_FMT_MJPEG to ONVIF JPEG encoding

The encoder options builder checked V4L2_PIX_FMT_JPEG only. Cameras
that report MJPG (the WB7022 and most UVC webcams) fell through both
H264 and JPEG branches, producing an encoder config with no Encoding
type set. Win11 then ignored the profile.

Regression: tests/unit/test_encoder_options.cpp::MJPGMapsToJpeg
```

## Stop and Ask

Stop and ask the user before any of these:

- `git push --force` / `--force-with-lease` on a branch with open PR
- `git rebase` on a branch with open PR
- `git reset --hard` outside a fresh worktree
- Closing or re-opening a PR
- Deleting a branch the user may not have pulled
- Pushing to master (branch protection rejects this anyway)

## PR Workflow

1. `make check` must pass before creating a PR.
2. Push the branch: `git push -u origin <branch>`.
3. Create the PR with the body format:

```markdown
## Summary
<1-3 bullet points>

## Why this is correct
<which failing test now passes, which gate now reports green>

## Test plan
- [ ] `make check` green
- [ ] L4 Win11 smoke check (if Discovery/Profile/StreamUri touched)
```

4. Address review findings inline; new push → new CI run → new review.
5. Merge with `gh pr merge <N> --squash --delete-branch`.

## Post-Merge Cleanup

```bash
git checkout master
git pull --ff-only origin master
git branch -d <branch>
git fetch --prune origin
```

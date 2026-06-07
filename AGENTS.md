# Agent Instructions

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work
is NOT complete until `git push` succeeds (when this is a clean repo) or
until the diff has been demonstrated green under `make check` (for the
current pre-CI state).

**MANDATORY WORKFLOW:**

1. **Stop all background processes** — `onvif-server.exe`, `tcpdump`,
   `mediamtx`, `ustreamer`, etc. Leave the camera bound to `uvcvideo` and
   ports 8080 / 8554 / 3702 free.
2. **Verify quality gates** if code changed:

   ```bash
   make check        # format + lint + cppcheck + tests + ASan + UBSan
   ```

   Zero warnings, zero errors. If gates fail, fix or revert before
   ending the session.
3. **File follow-up notes** for anything we identified but did not fix —
   in a bead, an issue, or `docs/DESIGN.md` as a "Future Work" ADR.
4. **Commit logically** — one concept per commit, message format from
   `docs/GIT.md`.
5. **Push to remote** when on a feature branch with no open PR
   conflicts. Stop and ask before any force-push.

## Critical Rules

- A behavior change without a regression test is incomplete work.
- Tests live with code: `tests/unit/test_<file>.cpp`,
  `tests/integration/test_<scenario>.cpp`.
- The Win11 manual test is a smoke check, not a substitute for ctest.
- `git push --force`, `git rebase` on a PR, `git reset --hard`: stop and ask.

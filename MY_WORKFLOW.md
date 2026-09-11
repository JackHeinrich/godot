# My D3D12 fix — personal workflow notes

## What this is
A fix for the ~7-month intermittent D3D12 freeze/crash on AMD (RX 6600 XT) that only
reproduced via the editor's Play/Stop/Reload workflow. Root cause: Godot's editor killed
Play-session child processes with a raw `TerminateProcess()` on Windows, giving the D3D12
swap chain zero chance to release cleanly — repeated abrupt kills raced with the AMD driver's
async cleanup of the fullscreen flip-model swap chain, eventually causing a multi-second
stall or a `DXGI_ERROR_DEVICE_RESET` crash.

Fix: added a batched, graceful-shutdown-first process termination path
(`OS::kill_multiple()`), used by the editor's Play/Stop/Reload teardown, that asks the game
window to close itself first (letting it release the swap chain normally) before falling
back to a hard kill only if it doesn't exit in time.

Fully tested: 20-30+ reload cycles with zero freezes, plus multi-instance stop timing and
debugger-paused stop scenarios, all clean.

## Repo setup
- `origin` → real upstream `godotengine/godot` (for pulling updates — never push here, no access anyway)
- `fork` → `https://github.com/JackHeinrich/godot` (mine — push here)
- `master` (local) → stays a pure, untouched mirror of `origin/master` (upstream's dev
  branch, currently working toward 4.8 — unfinished/unreleased). Never commit here. This is
  purely the base for PR branches, since PRs target `godotengine/godot:master`.
- `fix/d3d12-editor-kill-freeze` → the actual PR branch, branched off `master`. Contains only
  the fix, nothing personal. Currently pushed to `fork`. Any *new* future fix/feature also
  gets its own fresh branch off `master`, same pattern. (This stays on the dev base — PRs to
  upstream always target `master`, regardless of what `workspace` is built on below.)
- `workspace` → my personal daily-driver branch. **Not** based on `master`/dev anymore — as
  of 2026-09-11, rebased to build on top of the `4.7.2-stable` tag (the latest actual stable
  Godot release) instead, since running unfinished 4.8-dev day to day wasn't worth it. Has
  the d3d12 fix commit (ported onto the 4.7 codebase) plus `MY_WORKFLOW.md`/`build-dev.sh`/
  `build-optimized.sh`/`CLAUDE.md` committed directly on it (deliberately, since this branch is never PR'd — see
  below). Pushed to `fork` for backup (force-pushed, since it was rebased — see "Updating"
  below for why that's expected here). This is the branch I actually build and use day to day.
- Changed files (the actual fix, on `fix/d3d12-editor-kill-freeze`, and ported onto
  `workspace`'s 4.7 base): `core/os/os.h`, `core/os/os.cpp`, `platform/windows/os_windows.h`,
  `platform/windows/os_windows.cpp`, `editor/run/editor_run.h`, `editor/run/editor_run.cpp`,
  `editor/debugger/editor_debugger_node.h`, `editor/debugger/editor_debugger_node.cpp`
  - Note: `editor_debugger_node.h/.cpp` also declare `get_debugger_id()` on `master`/dev, but
    that's an unrelated upstream feature (used by `script_editor_debugger.cpp`) that landed
    *after* the 4.7 branch split — it doesn't exist on the 4.7 line and isn't part of this
    fix. Only `is_process_paused()` in that file is actually the fix's addition.

## Personal files (this one, build-dev.sh, build-optimized.sh, CLAUDE.md)
These are committed for real, but only on `workspace` -- never on `master` or any `fix/*`
branch. Since `master`/`fix/*` never had them in history to begin with, switching to either
just makes git remove them from the working folder automatically (nothing to configure,
no ignore rules needed); switching back to `workspace` brings them right back. So: they're
only visible/editable while checked out on `workspace`, and they can never end up in a PR,
since a PR only ever comes from a `fix/*` branch's own history.

New personal files should be added the same way: create the file, `git add` + commit it
while on `workspace`. Never add personal files to `master` or a `fix/*` branch.

## PR status
Not yet opened. When ready: open a PR from `fork:fix/d3d12-editor-kill-freeze` targeting
`godotengine/godot:master` (GitHub gave a direct link after the first push:
`https://github.com/JackHeinrich/godot/pull/new/fix/d3d12-editor-kill-freeze`).
Double-check the "base repository" is `godotengine/godot` before submitting.

If it's accepted: the fix will exist in real Godot's `master`. At that point, stop using
this branch and just build plain `origin/master` going forward.

If it's not accepted (or while waiting): keep using this branch indefinitely, see below.

## Keeping my daily build updated with upstream Godot

**`workspace` tracks the 4.7 *stable release* line now, not `master`/dev.** To pick up a
newer stable point release (e.g. when `4.7.3-stable` ships):
```
git fetch origin --tags
git checkout workspace
git merge 4.7.3-stable        # whatever the new tag is
```
This is a normal merge (linear stable-release history), so no force-push needed for this
part. If git reports conflicts: resolve them in the flagged files, then `git add <file>` each
resolved file and `git commit` to finish the merge.

`master` still exists purely as the clean base for PR branches (see "Repo setup" above) and
is unrelated to keeping `workspace` updated now. Update it only when preparing/rebasing a
`fix/*` PR branch:
```
git checkout master
git pull origin master
```
Never merge upstream directly into a `fix/*` PR branch's history in a way that pulls in
unrelated commits — if a `fix/*` PR branch itself needs to catch up with upstream (e.g. a
reviewer asks, or it's gone stale), that's a separate, deliberate action: `git checkout
fix/whatever` then `git merge origin/master` on that branch specifically -- don't do this
routinely, only when actually needed for that PR.

### Note: how `workspace` got moved from `master`/dev to `4.7.2-stable` (2026-09-11)
`workspace` used to be branched off `master` (dev/4.8-unfinished). It was rebased onto the
`4.7.2-stable` tag instead: `git rebase --onto 4.7.2-stable master workspace`, replaying the
fix commit + personal-file commits on top of the 4.7 codebase, then force-pushed to `fork`.
This was a one-time base change, not something to repeat routinely — see the merge-based
update flow above for normal ongoing updates. If `workspace` ever needs to move to a
*different* base again in the future (a new major/minor stable line, e.g. 4.8 once it's
actually released), the same `git rebase --onto <new-base> <old-base> workspace` pattern
applies, and conflicts in ported fix code should be checked carefully (a conflict can mean a
real semantic clash, or — as happened here with `get_debugger_id()` — just an unrelated
dev-only function that happened to sit next to the fix's actual change; check what each side
of a conflict is really adding before keeping both).

## Building
Two build scripts, from Git Bash, in the repo root -- pick based on what you're doing:

```
./build-dev.sh          # debug/dev build: unoptimized, keeps DEV_ENABLED assertions + debug info
./build-optimized.sh    # release-style build: full optimization + LTO, no dev assertions
```

`build-dev.sh` is slower to run (noticeably slower editor/game than the official download --
that's normal, not a bug) but is what makes bugs actually debuggable; it's what was used to
track down and verify the D3D12 freeze fix. `build-optimized.sh` compiles slower but the
resulting binary runs close to official-release speed -- use it when you just want to play
with the fix included, not debug something. Both copy their result into branch-prefixed
filenames in `bin\` (e.g. `workspace-godot.windows.editor.dev.x86_64.exe` from the dev script,
`workspace-godot.windows.editor.opt.x86_64.exe` from the optimized one), so builds from
different branches/build types don't overwrite each other and stay easy to tell apart. Run
either the plain or `.console` (has a debug console window) version directly as the editor.

These scripts only exist on `workspace` (see "Personal files" above) -- if either is ever
missing (e.g. freshly on a `fix/*` branch and want a one-off build there), fall back to the
raw commands they wrap:
```
# dev build
python -m SCons platform=windows target=editor dev_build=yes d3d12=yes accesskit=no use_pix=yes -j$(nproc)
# optimized build
python -m SCons platform=windows target=editor d3d12=yes accesskit=no lto=full -j$(nproc)
```
(PowerShell: replace `$(nproc)` with `$env:NUMBER_OF_PROCESSORS`.)

A small merge rebuilds in well under a couple minutes with `build-dev.sh`; a merge that
touches broad core headers can take several minutes, and `build-optimized.sh` (LTO) takes
noticeably longer than either -- that's normal, just let it finish.

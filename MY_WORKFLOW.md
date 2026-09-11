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
- `master` (local) → stays a pure, untouched mirror of `origin/master`. Never commit here.
- `fix/d3d12-editor-kill-freeze` → the actual PR branch, branched off `master`. Contains only
  the fix, nothing personal. Currently pushed to `fork`. Any *new* future fix/feature also
  gets its own fresh branch off `master`, same pattern.
- `workspace` → my personal daily-driver branch. Branched off `master`, has
  `fix/d3d12-editor-kill-freeze` merged into it, plus `MY_WORKFLOW.md` and `build.sh`
  committed directly on it (deliberately, since this branch is never PR'd — see below).
  Pushed to `fork` for backup. This is the branch I actually build and use day to day.
- Changed files (the actual fix, on `fix/d3d12-editor-kill-freeze`): `core/os/os.h`,
  `core/os/os.cpp`, `platform/windows/os_windows.h`, `platform/windows/os_windows.cpp`,
  `editor/run/editor_run.h`, `editor/run/editor_run.cpp`, `editor/debugger/editor_debugger_node.h`,
  `editor/debugger/editor_debugger_node.cpp`

## Personal files (this one, build.sh, CLAUDE.md)
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
Update `master`, then bring that into `workspace` (the branch I actually build/use) --
never merge upstream directly into a `fix/*` PR branch, that would defeat the point of
keeping it clean for review:
```
git checkout master
git pull origin master
git checkout workspace
git merge master
```
If git reports conflicts: resolve them in the flagged files, then `git add <file>` each
resolved file and `git commit` to finish the merge. Normal merge conflict resolution,
nothing special about it.

(Merge, not rebase — keeps this simple with no force-pushing ever required.)

If a `fix/*` PR branch itself needs to catch up with upstream (e.g. a reviewer asks, or it's
gone stale) that's a separate, deliberate action: `git checkout fix/whatever` then
`git merge origin/master` on that branch specifically -- don't do this routinely, only when
actually needed for that PR.

## Building
Just run, from Git Bash, in the repo root:
```
./build.sh
```
This runs the full SCons build and then copies the result into branch-prefixed filenames in
`bin\`, e.g. `workspace-godot.windows.editor.dev.x86_64.exe` when built from `workspace`, so
builds from different branches don't overwrite each other and stay easy to tell apart. Run
either the plain or `.console` (has a debug console window) version directly as the editor.

`build.sh` itself only exists on `workspace` (see "Personal files" above) -- if it's ever
missing (e.g. freshly on a `fix/*` branch and want a one-off build there), fall back to the
raw command it wraps:
```
python -m SCons platform=windows target=editor dev_build=yes d3d12=yes accesskit=no use_pix=yes -j$(nproc)
```
(PowerShell: replace `$(nproc)` with `$env:NUMBER_OF_PROCESSORS`.)

A small merge rebuilds in well under a couple minutes; a merge that touches broad core
headers can take several minutes — that's normal, just let it finish.

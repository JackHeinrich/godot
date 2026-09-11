# Project context for Claude

This is Jack's personal clone of Godot Engine (`godotengine/godot`), with a real, tested
fix for a ~7-month intermittent D3D12 freeze/crash on AMD GPUs (see `MY_WORKFLOW.md` for
the full technical writeup). It is being contributed upstream as a pull request.

## Branch structure — read before running any git command here
- `master` (local) → must stay a pure, untouched mirror of `origin/master` (real upstream
  Godot). Never commit here, ever.
- `fix/*` branches (e.g. `fix/d3d12-editor-kill-freeze`) → PR branches, each branched fresh
  off `master`. Contain only the actual fix being contributed, nothing personal. These get
  pushed to `fork` (`https://github.com/JackHeinrich/godot`) and PR'd to
  `godotengine/godot:master`.
- `workspace` → Jack's personal daily-driver branch. Branched off `master`, has the fix
  branch(es) merged in, plus personal files (`MY_WORKFLOW.md`, `build.sh`, this file)
  committed directly on it. Never PR'd. This is what actually gets built and used day to day.

Personal files belong only on `workspace`. Never commit them to `master` or a `fix/*`
branch — the whole point of this structure is that PR branches stay clean automatically.

## Standing instruction: keep MY_WORKFLOW.md current

**Whenever the workflow, branch structure, build process, or tooling changes in this repo,
update `MY_WORKFLOW.md` to match, in the same turn as the change** -- don't wait to be asked
again. That file is Jack's actual reference for how to use this repo without needing to ask
an AI every time; letting it drift out of date defeats its purpose. This includes things
like: a new personal script or file being added, the build command changing, the branch
structure changing, or the PR's status changing (opened/merged/closed).

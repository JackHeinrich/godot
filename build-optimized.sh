#!/usr/bin/env bash
# Personal build helper -- not part of Godot, tracked only on the `workspace` branch.
#
# Release-style build: full optimization + LTO, no dev_build assertions -- close to the
# official godotengine.org download's performance, with this repo's fix included. Takes
# noticeably longer to compile than build-dev.sh, and loses the extra debug assertions/
# debug info, so it's not the one to reach for while actively chasing a bug.
#
# Builds the Windows editor and copies the result into branch-prefixed filenames in
# bin/, so binaries built from different branches (workspace, master, a fix/* branch,
# etc.) don't overwrite each other and stay easy to tell apart at a glance.
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

# Slashes aren't valid in a single filename component (e.g. fix/d3d12-editor-kill-freeze).
BRANCH=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')

echo "Building branch: $BRANCH (optimized build)"
python -m SCons platform=windows target=editor d3d12=yes accesskit=no lto=full -j"$(nproc)"

for suffix in "" ".console"; do
    src="bin/godot.windows.editor.x86_64${suffix}.exe"
    dst="bin/${BRANCH}-godot.windows.editor.opt.x86_64${suffix}.exe"
    if [ -f "$src" ]; then
        cp -f "$src" "$dst"
        echo "-> $dst"
    fi
done

echo "Done."

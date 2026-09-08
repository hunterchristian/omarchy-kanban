#!/bin/bash
# Clone omarchy.lock into ~/.config/omarchy/plugins/<user>.lock (the same
# copy omarchy-plugin-clone makes) and add the read-only kanban Loader to its
# LockView.qml. Run again with --force after an Omarchy update so the clone
# picks up upstream lock-screen fixes.
set -euo pipefail

fail() { echo "install-lock.sh: $*" >&2; exit 1; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
kanban_id=$(jq -r '.id' "$here/manifest.json")
kanban_dir=$(basename "$here")
: "${OMARCHY_PATH:=/usr/share/omarchy}"
plugins_dir="$HOME/.config/omarchy/plugins"
config="$HOME/.config/omarchy/shell.json"
source_id="omarchy.lock"
source_dir="$OMARCHY_PATH/shell/plugins/lock"
new_id="${USER:-$(id -un)}.lock"
target="$plugins_dir/$new_id"
patch="$here/lock/LockView.kanban.qml"

force=0
[[ ${1:-} == "--force" ]] && force=1

[[ -f "$source_dir/manifest.json" ]] || fail "built-in lock plugin not found at $source_dir"
[[ -f "$patch" ]] || fail "patch snippet missing: $patch"
if [[ -e "$target" || -L "$target" ]]; then
  (( force )) || fail "$target already exists; pass --force to rebuild it from the current built-in"
fi

mkdir -p "$plugins_dir"
stage=$(mktemp -d "$plugins_dir/.lock-clone.XXXXXX")
trap 'rm -rf "$stage"' EXIT

cp -aL "$source_dir/." "$stage/"

# Same manifest rewrite omarchy-plugin-clone performs: keep the built-in id
# as the IPC target, and mark the clone so the shell routes to it.
jq --arg id "$new_id" --arg name "My Lock Screen" --arg sourceId "$source_id" '
  .id = $id |
  .name = $name |
  .omarchy = ((if (.omarchy | type) == "object" then .omarchy else {} end) + { clonedFrom: $sourceId }) |
  del(.omarchy.clonePaths)
' "$stage/manifest.json" >"$stage/manifest.json.tmp"
mv "$stage/manifest.json.tmp" "$stage/manifest.json"

# Insert the Loader before the full-screen MouseArea that follows the wallpaper
# blur, so the board draws above the blur and below the input handling.
view="$stage/LockView.qml"
grep -q "MultiEffect {" "$view" || fail "LockView.qml no longer has the MultiEffect anchor; update the patch"
sed -e "s|@@KANBAN_ID@@|$kanban_id|g" -e "s|@@KANBAN_DIR@@|$kanban_dir|g" "$patch" >"$stage/.patch"
awk -v patchfile="$stage/.patch" '
  /MultiEffect \{/ { seen = 1 }
  seen && !done && /^    MouseArea \{$/ {
    while ((getline line < patchfile) > 0) print line
    close(patchfile)
    done = 1
  }
  { print }
  END { if (!done) exit 3 }
' "$view" >"$view.tmp" || fail "could not find the MouseArea anchor in LockView.qml; update the patch"
mv "$view.tmp" "$view"
rm -f "$stage/.patch"

[[ -e "$target" ]] && rm -rf "$target"
mv "$stage" "$target"
trap - EXIT
echo "Cloned $source_id to $target with the kanban Loader"

shell_running() { omarchy-shell shell ping >/dev/null 2>&1; }

if shell_running; then
  omarchy-shell shell rescanPlugins >/dev/null
  omarchy-plugin-enable "$new_id"
  echo "Switched the lock screen to $new_id over shell IPC"
  exit 0
fi

mkdir -p "$(dirname "$config")"
[[ -f "$config" ]] || cp "$OMARCHY_PATH/config/omarchy/shell.json" "$config"
tmp=$(mktemp)
jq --arg id "$new_id" --arg sourceId "$source_id" '
  .plugins = ((.plugins // []) | if any(.[]; .id == $id) then . else . + [{ id: $id }] end) |
  .disabledPlugins = ((.disabledPlugins // []) + [$sourceId] | unique) |
  .cloneSourceRestores = ((.cloneSourceRestores // []) + [$id] | unique)
' "$config" >"$tmp"
mv "$tmp" "$config"
echo "Switched the lock screen to $new_id in $config (shell not running; takes effect at next shell start)"

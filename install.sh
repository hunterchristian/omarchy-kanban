#!/bin/bash
# Enable the kanban plugin in omarchy-shell.
# With the shell running this goes through shell IPC; without it (ssh, TTY)
# it edits ~/.config/omarchy/shell.json directly, which the shell reads at
# its next start.
set -euo pipefail

fail() { echo "install.sh: $*" >&2; exit 1; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
id=$(jq -r '.id' "$here/manifest.json")
plugins_dir="$HOME/.config/omarchy/plugins"
config="$HOME/.config/omarchy/shell.json"
: "${OMARCHY_PATH:=/usr/share/omarchy}"

[[ "$here" == "$plugins_dir/$id" ]] || fail "plugin must live at $plugins_dir/$id (found $here)"

shell_running() { omarchy-shell shell ping >/dev/null 2>&1; }

if shell_running; then
  omarchy-shell shell rescanPlugins >/dev/null
  omarchy-plugin-enable "$id"
  echo "Enabled $id over shell IPC"
  exit 0
fi

mkdir -p "$(dirname "$config")"
[[ -f "$config" ]] || cp "$OMARCHY_PATH/config/omarchy/shell.json" "$config"
tmp=$(mktemp)
jq --arg id "$id" '
  .plugins = ((.plugins // []) | if any(.[]; .id == $id) then . else . + [{ id: $id }] end)
' "$config" >"$tmp"
mv "$tmp" "$config"
echo "Enabled $id in $config (shell not running; takes effect at next shell start)"

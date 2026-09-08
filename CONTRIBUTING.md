# Contributing

Thanks for looking. This is a small plugin and small changes are welcome.

## Ground rules

- Open an issue first for anything bigger than a bug fix, so we agree on the
  shape before you write it.
- Keep the plugin dependency-free. It should need nothing beyond an Omarchy 4
  install (Quickshell, `jq`, `awk`).
- The lock-screen path is security-sensitive. Changes to
  `lock/LockView.kanban.qml` or `install-lock.sh` must keep the board
  read-only, must never take keyboard focus from the password field, and must
  keep loading through a `Loader` so a board failure cannot break the lock.
- No install-time surprises. Installing the plugin must never change user
  configuration on its own; the lock-screen clone stays an explicit,
  documented step.

## Working on it

```bash
git clone https://github.com/hunterchristian/omarchy-kanban.git \
  ~/.config/omarchy/plugins/hunterchristian.kanban
~/.config/omarchy/plugins/hunterchristian.kanban/install.sh
```

Saving a file under `~/.config/omarchy/plugins/` hot-reloads the plugin. If it
does not, run `omarchy-shell shell rescanPlugins`. QML errors show up in the
shell log (`journalctl --user -u omarchy-shell` or the terminal you launched
`omarchy-restart-shell` from).

Lint before you push:

```bash
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell -I /usr/lib/qt6/qml *.qml
```

Warnings about `qs.Commons` imports are expected (the linter cannot see the
shell's module root). Errors are not.

## Ideas that would be welcome

- Per-card notes or a due date, shown small under the title.
- A keybinding that focuses the add field of the first column.
- Column management from the UI (today: edit `board.json`).
- A Hyprland layer rule for blur behind the columns.
- Screenshots for the README and marketplace preview.

## Style

Short functions, explicit names, no clever tricks. Comments explain why, not
what. Plain hyphens, no em dashes.

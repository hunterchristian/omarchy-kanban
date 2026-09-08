# Kanban for Omarchy

A kanban board of todo cards that lives on the desktop background, and shows
read-only on the lock screen. A plugin for the Omarchy 4 shell
(`omarchy-shell`, Quickshell).

- Three columns by default: Todo, Doing, Done. Columns are editable in the
  data file.
- Drag a card between columns or to reorder. Double-click a card to edit it.
  Hover a card for the delete glyph. The last column has a "clear" action.
- Type in the field at the bottom of a column and press Enter to add a card.
- Cards persist in `~/.local/state/kanban/board.json`. The file is watched,
  so edits from a script or another Claude session appear at once.
- Clicks outside the board pass through to the wallpaper (double-click still
  opens the background picker).

## Install

```bash
git clone <this repo> ~/.config/omarchy/plugins/hunterhod.kanban
~/.config/omarchy/plugins/hunterhod.kanban/install.sh        # desktop board
~/.config/omarchy/plugins/hunterhod.kanban/install-lock.sh   # lock screen
```

Both scripts use shell IPC when `omarchy-shell` is running and edit
`~/.config/omarchy/shell.json` directly when it is not (for example over ssh).
Config edits made without the shell take effect at the next shell start.

## Lock screen

The lock screen is Omarchy's `omarchy.lock` plugin. `install-lock.sh` makes
the same personal clone that `omarchy plugin clone omarchy.lock` makes, then
inserts one `Loader` (see `lock/LockView.kanban.qml`) into `LockView.qml`.
The board renders above the blurred wallpaper and above the password field,
read-only: no drag, no edit, no input focus.

The Loader means a broken board renders nothing rather than breaking the
password field.

A cloned plugin no longer receives Omarchy's own updates to the lock screen.
After an Omarchy update, rebuild the clone from the new built-in:

```bash
~/.config/omarchy/plugins/hunterhod.kanban/install-lock.sh --force
```

To go back to the stock lock screen: `omarchy plugin remove hunterhod.lock`.

Anything on the board is visible to anyone at the locked machine.

## IPC

```bash
omarchy-shell kanban add todo "Write the release notes"   # prints the new card id
omarchy-shell kanban move <id> doing
omarchy-shell kanban done <id>
omarchy-shell kanban remove <id>
omarchy-shell kanban clear done
omarchy-shell kanban list                                  # JSON
omarchy-shell kanban reload
```

## Data file

```json
{
  "version": 1,
  "columns": [
    { "id": "todo", "title": "Todo" },
    { "id": "doing", "title": "Doing" },
    { "id": "done", "title": "Done" }
  ],
  "cards": [
    { "id": "k3f9a1x", "column": "todo", "title": "Write the release notes",
      "order": 0, "createdAt": "2026-09-08T21:00:00.000Z" }
  ]
}
```

Invalid JSON is ignored and the last good state stays on screen. Cards whose
column no longer exists fall into the first column.

## Layout

- `Service.qml`: desktop window per screen on the `Bottom` layer-shell layer
  (above the wallpaper, below windows), the `kanban` IPC target.
- `KanbanBoard.qml`: the board. `readOnly` disables every interaction.
- `KanbanStore.qml`: the JSON file store.
- `LockBoard.qml`: read-only wrapper the lock clone loads.
- `lock/LockView.kanban.qml`: the snippet inserted into the cloned lock view.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons

// Desktop kanban: one layer-shell window per screen on the Bottom layer, so
// it sits above the wallpaper and below every app window. Input is masked to
// the board itself so clicks elsewhere still reach the wallpaper plugin.
Item {
  id: root

  property int margin: 48

  KanbanStore {
    id: store
  }

  // omarchy-shell kanban <method> [args]
  //   add <column> <title>     -> new card id
  //   move <id> <column>       -> ok | unknown
  //   done <id>                -> ok | unknown   (moves to the last column)
  //   remove <id>              -> ok | unknown
  //   clear <column>           -> number removed
  //   list                     -> JSON {columns, cards}
  //   reload                   -> re-read board.json
  IpcHandler {
    target: "kanban"

    function add(column: string, title: string): string {
      return store.add(column, title) || "unknown column or empty title"
    }

    function move(id: string, column: string): string {
      return store.move(id, column, -1) ? "ok" : "unknown card or column"
    }

    function done(id: string): string {
      return store.move(id, store.lastColumnId(), -1) ? "ok" : "unknown card"
    }

    function remove(id: string): string {
      return store.remove(id) ? "ok" : "unknown card"
    }

    function clear(column: string): string {
      return String(store.clearColumn(column))
    }

    function list(): string {
      return JSON.stringify({ columns: store.columns, cards: store.cards })
    }

    function reload(): void {
      store.reload()
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"

      WlrLayershell.namespace: "omarchy-kanban"
      WlrLayershell.layer: WlrLayer.Bottom
      // OnDemand: the board gets keyboard focus only when clicked, and
      // gives it back when a window is focused.
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      // Reserve nothing, but respect the bar's reserved edge.
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: 0

      mask: Region { item: kanban.inputRegionItem }

      KanbanBoard {
        id: kanban
        anchors.fill: parent
        anchors.margins: root.margin
        store: store
      }
    }
  }
}

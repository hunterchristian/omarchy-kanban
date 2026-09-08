import QtQuick

// Read-only board for the lock screen. Own store instance so the file watcher
// keeps it current while locked. Loaded by the cloned lock plugin through a
// Loader, so a failure here never reaches the password field.
Item {
  id: root

  KanbanStore {
    id: store
  }

  KanbanBoard {
    anchors.fill: parent
    store: store
    readOnly: true
  }
}

    // Kanban board (@@KANBAN_ID@@), read-only while locked. Loaded through a
    // Loader so a broken board can never take the password field down with it.
    // Re-applied by install-lock.sh after an Omarchy update re-clones the lock.
    Loader {
      id: kanbanLoader
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: inputField.top
      anchors.margins: 48
      active: root.loadBackground
      asynchronous: true
      source: Qt.resolvedUrl("../@@KANBAN_DIR@@/LockBoard.qml")
    }


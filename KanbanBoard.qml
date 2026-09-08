import QtQuick
import qs.Commons

// The board: one column per store column, cards inside, drag between columns,
// double-click to edit, an add field per column. `readOnly` turns every
// interaction off (used on the lock screen) while keeping the layout.
Item {
  id: board

  property var store: null
  property bool readOnly: false
  property int maxWidth: 1400
  property int columnGap: 16
  property int cardGap: 8
  property int pad: 12

  // The region that should receive pointer input. The desktop window masks
  // to this so clicks outside the board still reach the wallpaper.
  readonly property Item inputRegionItem: frame

  readonly property var columns: store ? store.columns : []
  readonly property int revision: store ? store.revision : 0

  // `revision` is unused inside, but reading it in the binding makes the
  // card list re-evaluate on every store change.
  function cardsFor(columnId, revision) {
    return store ? store.cardsIn(columnId) : []
  }

  property string editingId: ""

  // Drag state. The dragged card stays in place (dimmed) and a ghost follows
  // the pointer at board level, so nothing has to be reparented out of a
  // clipped list mid-drag.
  property string dragId: ""
  property string dragTitle: ""
  property real dragX: 0
  property real dragY: 0
  property real dragOffsetX: 0
  property real dragOffsetY: 0
  property real dragWidth: 200
  property int dropColumnIndex: -1
  readonly property bool dragging: dragId !== ""

  function columnIndexAt(x, y) {
    for (var i = 0; i < columnRepeater.count; i++) {
      var col = columnRepeater.itemAt(i)
      if (!col) continue
      var local = board.mapToItem(col, x, y)
      if (local.x >= 0 && local.x <= col.width && local.y >= 0 && local.y <= col.height) return i
    }
    return -1
  }

  function beginDrag(cardId, title, x, y, offsetX, offsetY, width) {
    if (readOnly || !store) return
    editingId = ""
    dragId = cardId
    dragTitle = title
    dragOffsetX = offsetX
    dragOffsetY = offsetY
    dragWidth = width
    updateDrag(x, y)
  }

  function updateDrag(x, y) {
    dragX = x
    dragY = y
    dropColumnIndex = columnIndexAt(x, y)
  }

  function endDrag(x, y) {
    var id = dragId
    var index = columnIndexAt(x, y)
    if (id && store && index >= 0) {
      var col = columnRepeater.itemAt(index)
      var local = board.mapToItem(col, x, y)
      store.move(id, col.columnId, col.insertIndexAt(local.y, id))
    }
    cancelDrag()
  }

  function cancelDrag() {
    dragId = ""
    dragTitle = ""
    dropColumnIndex = -1
  }

  Item {
    id: frame
    width: Math.min(parent.width, board.maxWidth)
    height: parent.height
    anchors.horizontalCenter: parent.horizontalCenter

    Row {
      id: row
      anchors.fill: parent
      spacing: board.columnGap

      Repeater {
        id: columnRepeater
        model: board.columns

        Item {
          id: column

          required property var modelData
          required property int index

          readonly property string columnId: modelData.id
          readonly property string title: modelData.title
          readonly property bool isLast: index === board.columns.length - 1
          readonly property bool dropTarget: board.dragging && board.dropColumnIndex === index
          readonly property var cardList: board.cardsFor(columnId, board.revision)

          width: Math.floor((row.width - board.columnGap * Math.max(0, board.columns.length - 1)) / Math.max(1, board.columns.length))
          height: row.height

          // Index among this column's cards (excluding `excludeId`) that a drop
          // at column-local `y` should land on.
          function insertIndexAt(y, excludeId) {
            var local = column.mapToItem(cardsColumn, 0, y)
            var idx = 0
            for (var i = 0; i < cardRepeater.count; i++) {
              var item = cardRepeater.itemAt(i)
              if (!item || item.cardId === excludeId) continue
              if (local.y > item.y + item.height / 2) idx += 1
            }
            return idx
          }

          Rectangle {
            anchors.fill: parent
            color: Util.alpha(Color.background, column.dropTarget ? 0.6 : 0.45)
            border.width: 1
            border.color: column.dropTarget ? Color.accent : Util.alpha(Color.foreground, 0.16)
            radius: Style.cornerRadius
          }

          Column {
            id: columnBody
            anchors.fill: parent
            anchors.margins: board.pad
            spacing: board.pad

            Item {
              id: header
              width: parent.width
              height: headerText.implicitHeight + 6

              Text {
                id: headerText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: column.title.toUpperCase()
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.letterSpacing: 2
                font.bold: true
              }

              Text {
                anchors.left: headerText.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: column.cardList.length
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
              }

              Text {
                id: clearButton
                visible: !board.readOnly && column.isLast && column.cardList.length > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: clearArea.containsMouse ? "clear all" : "clear"
                color: clearArea.containsMouse ? Color.urgent : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall

                MouseArea {
                  id: clearArea
                  anchors.fill: parent
                  anchors.margins: -4
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: board.store.clearColumn(column.columnId)
                }
              }
            }

            Flickable {
              id: list
              width: parent.width
              height: parent.height - header.height - board.pad - (addField.visible ? addField.height + board.pad : 0)
              contentHeight: cardsColumn.height
              clip: true
              // Card drags are vertical too, so the list must not grab them.
              // Wheel scrolling is handled below.
              interactive: false
              boundsBehavior: Flickable.StopAtBounds

              WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                  var max = Math.max(0, list.contentHeight - list.height)
                  list.contentY = Util.clamp(list.contentY - event.angleDelta.y, 0, max)
                }
              }

              Text {
                visible: column.cardList.length === 0
                x: 2
                y: 4
                text: column.index === 0 ? "Nothing to do" : "Empty"
                color: Util.alpha(Color.foreground, 0.35)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.italic: true
              }

              Column {
                id: cardsColumn
                width: list.width
                spacing: board.cardGap

                Repeater {
                  id: cardRepeater
                  model: column.cardList

                  Item {
                    id: card

                    required property var modelData
                    required property int index

                    readonly property string cardId: modelData.id
                    readonly property string cardTitle: modelData.title
                    readonly property bool editing: board.editingId === cardId
                    readonly property bool beingDragged: board.dragId === cardId
                    readonly property bool hot: cardArea.containsMouse && !board.dragging

                    width: cardsColumn.width
                    height: cardBody.height
                    opacity: beingDragged ? 0.35 : 1

                    function startEdit() {
                      if (board.readOnly) return
                      editor.text = card.cardTitle
                      board.editingId = card.cardId
                      editor.forceActiveFocus()
                      editor.selectAll()
                    }

                    function commitEdit() {
                      if (!card.editing) return
                      var next = editor.text.trim()
                      board.editingId = ""
                      if (next && next !== card.cardTitle) board.store.update(card.cardId, next)
                    }

                    Rectangle {
                      id: cardBody
                      width: parent.width
                      height: contentColumn.height + 20
                      color: Util.alpha(Color.background, card.hot || card.editing ? 0.9 : 0.75)
                      border.width: 1
                      border.color: card.editing ? Color.accent : Util.alpha(Color.foreground, card.hot ? 0.3 : 0.14)
                      radius: Style.cornerRadius

                      Column {
                        id: contentColumn
                        x: 10
                        y: 10
                        width: parent.width - 20 - (deleteGlyph.visible ? 16 : 0)

                        Text {
                          visible: !card.editing
                          width: parent.width
                          text: card.cardTitle
                          wrapMode: Text.Wrap
                          color: column.isLast ? Color.muted : Color.foreground
                          font.family: Style.font.family
                          font.pixelSize: Style.font.body
                          font.strikeout: column.isLast
                        }

                        TextEdit {
                          id: editor
                          visible: card.editing
                          width: parent.width
                          wrapMode: TextEdit.Wrap
                          color: Color.foreground
                          selectionColor: Util.alpha(Color.accent, 0.45)
                          selectedTextColor: Color.foreground
                          font.family: Style.font.family
                          font.pixelSize: Style.font.body
                          Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                              board.editingId = ""
                              event.accepted = true
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                       && !(event.modifiers & Qt.ShiftModifier)) {
                              card.commitEdit()
                              event.accepted = true
                            }
                          }
                          onActiveFocusChanged: if (!activeFocus) card.commitEdit()
                        }
                      }

                      Text {
                        id: deleteGlyph
                        z: 2
                        visible: !board.readOnly && card.hot && !card.editing
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 4
                        anchors.rightMargin: 8
                        text: "×"
                        color: deleteArea.containsMouse ? Color.urgent : Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading

                        MouseArea {
                          id: deleteArea
                          anchors.fill: parent
                          anchors.margins: -4
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: board.store.remove(card.cardId)
                        }
                      }
                    }

                    MouseArea {
                      id: cardArea
                      anchors.fill: parent
                      enabled: !board.readOnly && !card.editing
                      hoverEnabled: true
                      cursorShape: board.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                      property bool armed: false
                      property real pressX: 0
                      property real pressY: 0

                      onPressed: function(mouse) {
                        armed = true
                        pressX = mouse.x
                        pressY = mouse.y
                      }
                      onPositionChanged: function(mouse) {
                        var p = cardArea.mapToItem(board, mouse.x, mouse.y)
                        if (board.dragging) {
                          board.updateDrag(p.x, p.y)
                          return
                        }
                        if (!armed) return
                        if (Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) > 6) {
                          board.beginDrag(card.cardId, card.cardTitle, p.x, p.y, pressX, pressY, card.width)
                        }
                      }
                      onReleased: function(mouse) {
                        armed = false
                        if (!board.dragging) return
                        var p = cardArea.mapToItem(board, mouse.x, mouse.y)
                        board.endDrag(p.x, p.y)
                      }
                      onCanceled: {
                        armed = false
                        if (board.dragging) board.cancelDrag()
                      }
                      onDoubleClicked: card.startEdit()
                    }
                  }
                }
              }
            }

            Rectangle {
              id: addField
              visible: !board.readOnly
              width: parent.width
              height: 34
              color: Util.alpha(Color.background, addInput.activeFocus ? 0.9 : 0.5)
              border.width: 1
              border.color: addInput.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.14)
              radius: Style.cornerRadius

              TextInput {
                id: addInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Color.foreground
                selectionColor: Util.alpha(Color.accent, 0.45)
                selectedTextColor: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                onAccepted: {
                  var next = text.trim()
                  if (!next) return
                  board.store.add(column.columnId, next)
                  text = ""
                }
                Keys.onEscapePressed: {
                  text = ""
                  focus = false
                }
              }

              Text {
                visible: addInput.text.length === 0 && !addInput.activeFocus
                anchors.fill: addInput
                verticalAlignment: Text.AlignVCenter
                text: "+ Add a card"
                color: Util.alpha(Color.foreground, 0.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }
        }
      }
    }
  }

  // Ghost that follows the pointer while dragging.
  Rectangle {
    id: ghost
    z: 100
    visible: board.dragging
    x: board.dragX - board.dragOffsetX
    y: board.dragY - board.dragOffsetY
    width: board.dragWidth
    height: ghostText.implicitHeight + 20
    color: Util.alpha(Color.background, 0.95)
    border.width: 1
    border.color: Color.accent
    radius: Style.cornerRadius

    Text {
      id: ghostText
      x: 10
      y: 10
      width: parent.width - 20
      text: board.dragTitle
      wrapMode: Text.Wrap
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  Text {
    visible: board.store && board.store.lastError.length > 0
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    text: board.store ? board.store.lastError : ""
    color: Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}

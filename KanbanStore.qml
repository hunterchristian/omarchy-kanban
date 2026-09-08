import QtQuick
import Quickshell
import Quickshell.Io

// JSON-backed board state. One file, watched for changes, so every board in
// the shell (desktop, lock screen) and any outside writer (a script, a Claude
// session) stay in sync without an IPC round trip.
//
// File shape (~/.local/state/kanban/board.json):
//   { "version": 1,
//     "columns": [ { "id": "todo", "title": "Todo" }, ... ],
//     "cards": [ { "id": "k3f...", "column": "todo", "title": "...", "order": 0,
//                  "createdAt": "2026-09-08T21:00:00.000Z" }, ... ] }
Item {
  id: store

  readonly property string home: Quickshell.env("HOME")
  readonly property string dir: home + "/.local/state/kanban"
  readonly property string path: dir + "/board.json"

  property var columns: defaultColumns()
  property var cards: []
  // Bumped on every change so bindings that call cardsIn() re-evaluate.
  property int revision: 0
  property bool ready: false
  property string lastError: ""

  function defaultColumns() {
    return [
      { id: "todo", title: "Todo" },
      { id: "doing", title: "Doing" },
      { id: "done", title: "Done" }
    ]
  }

  function hasColumn(columnId) {
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].id === columnId) return true
    }
    return false
  }

  function lastColumnId() {
    return columns.length ? columns[columns.length - 1].id : ""
  }

  function cardsIn(columnId) {
    var out = []
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].column === columnId) out.push(cards[i])
    }
    out.sort(function(a, b) { return a.order - b.order })
    return out
  }

  function find(cardId) {
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].id === cardId) return cards[i]
    }
    return null
  }

  function newId() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 8)
  }

  function parse(raw) {
    var text = String(raw || "").trim()
    if (!text) {
      columns = defaultColumns()
      cards = []
      lastError = ""
      ready = true
      revision += 1
      return
    }

    var data
    try {
      data = JSON.parse(text)
    } catch (e) {
      // Keep the last good state on screen; a half-written file must not
      // wipe the board.
      lastError = "board.json is not valid JSON: " + e
      console.warn("kanban: " + lastError)
      ready = true
      return
    }

    var nextColumns = []
    var seen = {}
    var rawColumns = Array.isArray(data.columns) ? data.columns : []
    for (var c = 0; c < rawColumns.length; c++) {
      var col = rawColumns[c]
      if (!col || typeof col.id !== "string" || !col.id || seen[col.id]) continue
      seen[col.id] = true
      nextColumns.push({ id: col.id, title: typeof col.title === "string" && col.title ? col.title : col.id })
    }
    if (!nextColumns.length) {
      nextColumns = defaultColumns()
      seen = { todo: true, doing: true, done: true }
    }

    var nextCards = []
    var rawCards = Array.isArray(data.cards) ? data.cards : []
    for (var k = 0; k < rawCards.length; k++) {
      var card = rawCards[k]
      if (!card || typeof card.id !== "string" || !card.id) continue
      if (typeof card.title !== "string" || !card.title.trim()) continue
      var column = seen[card.column] ? card.column : nextColumns[0].id
      nextCards.push({
        id: card.id,
        column: column,
        title: card.title,
        order: isFinite(Number(card.order)) ? Number(card.order) : k,
        createdAt: typeof card.createdAt === "string" ? card.createdAt : ""
      })
    }

    columns = nextColumns
    cards = nextCards
    lastError = ""
    ready = true
    revision += 1
  }

  function serialize() {
    return JSON.stringify({ version: 1, columns: columns, cards: cards }, null, 2) + "\n"
  }

  function commit(nextCards) {
    cards = nextCards
    revision += 1
    file.setText(serialize())
  }

  // Rebuild the card list with `columnId` renumbered 0..n in the given order.
  function withColumn(columnId, ordered) {
    var next = []
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].column !== columnId) next.push(cards[i])
    }
    for (var j = 0; j < ordered.length; j++) {
      next.push(Object.assign({}, ordered[j], { column: columnId, order: j }))
    }
    return next
  }

  function add(columnId, title) {
    title = String(title || "").trim()
    if (!title || !hasColumn(columnId)) return ""
    var id = newId()
    var ordered = cardsIn(columnId)
    ordered.push({ id: id, column: columnId, title: title, order: ordered.length, createdAt: new Date().toISOString() })
    commit(withColumn(columnId, ordered))
    return id
  }

  // Move a card into `columnId` at `index` (position among the other cards of
  // that column, the moved card excluded). Out-of-range or missing index
  // appends.
  function move(cardId, columnId, index) {
    var card = find(cardId)
    if (!card || !hasColumn(columnId)) return false
    var ordered = cardsIn(columnId).filter(function(c) { return c.id !== cardId })
    var at = Number(index)
    if (!isFinite(at) || at < 0 || at > ordered.length) at = ordered.length
    ordered.splice(at, 0, card)
    var next = withColumn(columnId, ordered)
    if (card.column !== columnId) {
      // Renumber the source column too so its orders stay dense.
      var source = cardsIn(card.column).filter(function(c) { return c.id !== cardId })
      var rest = next.filter(function(c) { return c.column !== card.column })
      for (var j = 0; j < source.length; j++) rest.push(Object.assign({}, source[j], { order: j }))
      next = rest
    }
    commit(next)
    return true
  }

  function update(cardId, title) {
    title = String(title || "").trim()
    if (!title || !find(cardId)) return false
    var next = cards.map(function(c) { return c.id === cardId ? Object.assign({}, c, { title: title }) : c })
    commit(next)
    return true
  }

  function remove(cardId) {
    var card = find(cardId)
    if (!card) return false
    var ordered = cardsIn(card.column).filter(function(c) { return c.id !== cardId })
    commit(withColumn(card.column, ordered))
    return true
  }

  function clearColumn(columnId) {
    if (!hasColumn(columnId)) return 0
    var removed = cardsIn(columnId).length
    if (removed) commit(withColumn(columnId, []))
    return removed
  }

  function reload() {
    file.reload()
  }

  Process {
    id: ensureDir
    command: ["mkdir", "-p", store.dir]
    running: true
  }

  FileView {
    id: file
    path: store.path
    watchChanges: true
    atomicWrites: true
    printErrors: false
    // text() is stale inside the change signal itself, so route through
    // reload() -> loaded to always parse fresh content.
    onFileChanged: reload()
    onLoaded: store.parse(text())
    onLoadFailed: function(error) {
      // A missing file is the fresh-install state, not an error.
      store.columns = store.defaultColumns()
      store.cards = []
      store.ready = true
      store.revision += 1
    }
    onSaveFailed: function(error) {
      store.lastError = "could not write " + store.path
      console.warn("kanban: " + store.lastError)
    }
  }
}

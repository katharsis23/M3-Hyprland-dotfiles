# AI Sidebar — Interface & Requirements Specification

This document specifies the **AI sidebar** for the Quickshell shell: the chat
window, character picker, settings, and character-creation flows, plus the
exact interface they must speak to the Python backend bridge.

It is written for implementation against the existing codebase, so every
section names the concrete files, QML atoms, and backend methods it must use.

---

## 1. Architecture

```
┌──────────────────────────────┐        stdio (JSON lines)        ┌───────────────────────────┐
│  Quickshell (QML process)     │  ──────────────────────────────► │  Python backend process    │
│                               │                                  │                            │
│  AiSidebar.qml                │   {"id":1,"method":"chat.send",  │  ipc_server.BridgeServer   │
│   └─ AiChatWidget.qml         │    "params":{"text":"hi"}}       │   ├─ ChatPresenter         │
│       CharacterPicker…        │                                  │   ├─ CharacterPresenter    │
│       SettingsView…           │  ◄────────────────────────────── │   ├─ ThemePresenter        │
│  core/AiBridge.qml (singleton)│   {"id":1,"ok":true,"result":…}  │   └─ FilesystemBrowser     │
└──────────────────────────────┘   {"event":"reply","data":…}     └───────────────────────────┘
```

**Hard constraint:** Quickshell runs its own QML engine in a separate process
and **cannot import the backend's PySide6 `QObject`s**. All communication goes
through the JSON-over-stdio bridge (`src/ai_girlfriend/ui/ipc_server.py`) via
the `AiBridge` singleton. No direct sockets, HTTP, or shared memory.

**Why stdio:** Quickshell's `Process` + `SplitParser` read newline-delimited
output natively (the same pattern `AiChatWidget.qml` already uses for Ollama).
No ports to allocate, no CORS, dies with the parent.

---

## 2. Files this feature owns

| File | Role | Status |
|------|------|--------|
| `shell/qt/core/AiBridge.qml` | Singleton transport + state proxy | **exists** |
| `shell/qt/core/qmldir` | registers `singleton AiBridge 1.0` | **exists** |
| `shell/qt/widgets/AiChatWidget.qml` | Chat window (stub now) | **exists** |
| `shell/qt/windows/AiSidebar.qml` | Left drawer host | exists |
| `shell/qt/widgets/CharacterPicker.qml` | Character list/grid | *to create* |
| `shell/qt/widgets/CharacterEditor.qml` | Create/edit character | *to create* |
| `shell/qt/widgets/ChatHistoryView.qml` | Past conversations | *to create* |
| `shell/qt/widgets/AiSettingsView.qml` | Settings (theme/model/appearance) | *to create* |
| `shell/qt/components/FileBrowser.qml` | Read-only image picker | *to create* |
| `shell/qt/components/Portrait.qml` | Portrait-or-emoji avatar | *to create* |

All new files live under `shell/qt/` and use the existing atoms/theme — do not
introduce a new component or styling system.

---

## 3. Transport contract (AiBridge)

### 3.1 Wire format

One JSON object per line, UTF-8, newline-terminated.

```
request   : {"id": <int>, "method": <str>, "params": {…}}
response  : {"id": <int>, "ok": true,  "result": <any>}
error     : {"id": <int>, "ok": false, "error": "<message>"}
event     : {"event": <str>, "data": <any>}          # server push, no id
```

The backend emits `{"event":"ready","data":{"version":"1.0"}}` on startup.
Requests are dispatched **concurrently** server-side, so responses may arrive
out of order — always correlate by `id`.

### 3.2 AiBridge public surface (QML-facing)

Widgets MUST consume these properties/signals rather than talking to `Process`.

**Readiness**

- `bool ready` — backend handshake complete (emit-driven; gates the UI).
- `bool starting` — process launched but not yet `ready`.
- `string lastError` — last failure message (`""` when healthy).
- `string version` — backend protocol version.
- `void restart()` — kill and respawn the child process.

**Chat state (mirror of `chat.header`)**

- `string characterName`, `string characterId`
- `string greeting`
- `string initialExpression` — expression id to show before any reply.
- `string portraitEmoji` — emoji fallback when no image resolves.
- `string expression` — current emotion id (updates on each reply).
- `string expressionUrl` — `file://` portrait URL; **empty ⇒ render emoji.**
- `bool busy` — a `chat.send` is in flight.
- `string chatId` — active conversation id (`""` for a fresh chat).

**Collections**

- `var characterIds` — `["aria","nova", …]`
- `var chats` — `[{id, preview, count, updated}, …]`
- `var transcript` — `[{role, text}, …]` after `loadChat`
- `var themeIds`, `string themeId`

**Signals**

- `replyReceived(payload)` — `{role,text,expression,chatId}` for each assistant turn.
- `errorRaised(string message)`
- `chatLoaded(var transcript)` — full transcript after `loadChat`.
- `charactersListed(var ids)`, `themesListed(var ids)`

**Commands (thin wrappers — prefer these over `request`)**

| Function | Effect |
|----------|--------|
| `send(text)` | set `busy`, send `chat.send`; reply arrives via `replyReceived`. |
| `resetChat()` | clear transcript, restore `initialExpression`. |
| `refreshChats()` | reload `chats` from `chat.list`. |
| `loadChat(id)` | fetch `chat.load`; updates `transcript`, emits `chatLoaded`. |
| `selectCharacter(id)` | rebuild pipeline, update header, clear transcript. |
| `characterInfo(id, cb)` | `cb(info)` with editor prefill. |
| `newCharacterTemplate(cb)` | `cb(template)` blank form for create. |
| `saveCharacter(form, cb)` | create/update then reselect; `cb({id})`. |
| `deleteCharacter(id, cb)` | remove custom character; `cb({deleted})`. |
| `refreshThemes()`, `themeInfo(id, cb)` | theme list / detail. |
| `fsHome(cb)`, `fsList(path, cb)`, `fsParent(path, cb)` | image picker. |
| `request(method, params, cb)` | raw escape hatch: `cb(result, ok, error)`. |

> **Rule:** any new backend capability MUST be added as a method in
> `ipc_server.py` *and* get a wrapper here. Widgets never touch `Process`.

### 3.3 Backend method reference (source of truth)

`src/ai_girlfriend/ui/ipc_server.py` handlers:

```
app.ping            {}                          -> {pong, version}
chat.send           {text}                      -> {accepted}   (+ "reply" event)
chat.header         {}                          -> {characterName,characterId,greeting,
                                                     initialExpression,portraitEmoji,busy,chatId}
chat.expressionUrl  {expression}                -> {url}
chat.reset          {}                           -> {ok}
chat.list           {limit?}                     -> {chats:[{id,preview,count,updated}]}
chat.load           {chatId}                     -> {transcript:[{role,text}]}
characters.list     {}                           -> {ids:[…], current}
characters.info     {id}                         -> {id,name,personality,greeting_message,
                                                     initial_expression,expression,temperature,
                                                     max_tokens,custom,thumb,emoji,photos}
characters.select   {id}                         -> {selected, header}
characters.save     {name,personality,greeting_message,initial_expression,
                     temperature,max_tokens,photo_emoji_map,original_id?} -> {id, header}
characters.delete   {id}                         -> {deleted}
characters.template {}                           -> {name,personality,greeting_message,
                                                     initial_expression,temperature,max_tokens,photo_emoji_map}
themes.list         {}                           -> {ids, current}
themes.info         {id}                         -> {id,name,dark,custom,primary,secondary,
                                                     tertiary,background,surface,onSurface,colors}
themes.select       {id}                         -> {selected}
themes.save         {id,name,dark,colors}        -> {id}
themes.delete       {id}                         -> {deleted}
fs.home             {}                           -> {home,cwd}
fs.list             {path}                       -> {entries:[{name,path,isDir,url}]}
fs.setCwd           {path}                       -> {cwd}
fs.parent           {path}                       -> {path}
```

Events: `ready`, `reply` (`{role,text,expression,chatId}`), `error` (`{message}`).

---

## 4. UI requirements

All views use existing atoms: `M3Panel`, `M3Card`, `M3TextField`, `M3Button`,
`M3IconButton`, `M3Segmented`, `M3Tile`, `M3Dialog`, `M3Flickable`, `M3Text`,
`M3Icon`, and theme singletons `M3Theme`, `M3Tokens`, `Typography`.
Spacing/corners/durations come from `M3Tokens`; colors only from `M3Theme`
roles (`surface`, `surfaceContainerHigh`, `primary`, `primaryContainer`,
`primaryContainerFg`, `fg`, `fgMuted`, `outline`, `error`). Never hardcode
hex colors or pixel values.

### 4.1 Host & navigation

- Lives in the **left** drawer `AiSidebar.qml`; opened with `SUPER+ALT+L`
  (`IpcHandler.toggleAiSidebar` → `ConfigProvider.toggleLeftSidebar`).
- Header: leading back-affordance + title + trailing actions
  (history, new chat, settings).
- Content is a **view switcher** with these pages: `chat` (default), `history`,
  `characters`, `editor`, `settings`. Keep the active page in a local
  `property string page` on `AiSidebar`; do not add global state.
- On open, do not block on the backend: show a "Connecting…" skeleton until
  `AiBridge.ready`.

### 4.2 Chat window (`AiChatWidget.qml`)

- **Portrait** (`Portrait.qml`): round avatar. `source = AiBridge.expressionUrl`;
  when empty or not `Image.Ready`, show `AiBridge.portraitEmoji` centered on
  `primaryContainer`. Size token-driven (≈40dp in header, larger in empty state).
- **Header row:** portrait, name (`AiBridge.characterName`), subline = current
  `expression` (or "connecting…" while `!ready`).
- **Transcript:** `ListView` of bubbles; user right-aligned `primaryContainer`,
  assistant left `surfaceContainerHigh`; `positionViewAtEnd` on count change.
  Seed first assistant bubble with `AiBridge.greeting`.
- **Busy state:** while `AiBridge.busy`, disable composer and show a
  `TypingIndicator` (three-dot) bubble; composer placeholder "Thinking…".
- **Composer:** `M3TextField` + send `M3IconButton`; `onAccepted` sends.
  Disabled until `ready`.
- **Errors:** `errorRaised` surfaced as a transient inline bubble/toast.
- **History hooks:** a history button switches to `ChatHistoryView`.

### 4.3 Chat history (`ChatHistoryView.qml`)

- List `AiBridge.chats` (`M3Tile` per row: `preview`, `updated`, `count`).
- On open: `AiBridge.loadChat(id)` → switch back to `chat`, transcript renders
  from `chatLoaded`.
- "New chat" button → `resetChat()`, back to `chat`.

### 4.4 Character picker (`CharacterPicker.qml`)

- Grid/list over `AiBridge.characterIds`; each card built via
  `AiBridge.characterInfo(id, cb)` → portrait (`thumb` image or `emoji`),
  name, a short personality excerpt, and a "current" highlight when
  `id === AiBridge.characterId`.
- Tap → `selectCharacter(id)`; return to `chat` with a reset transcript.
- Card menu: **Edit** (open editor prefilled), **Delete** (only when
  `custom === true`, guarded by `M3Dialog`), **Set active**.
- FAB / primary button → **New character** (`newCharacterTemplate` → editor).

### 4.5 Character editor (`CharacterEditor.qml`)

Two modes: **create** (blank template) and **edit** (prefilled via
`characterInfo`, carrying `original_id`).

Fields:

- `M3TextField` **Name** (required — disable Save while empty).
- `M3TextField` **Personality** (multiline).
- `M3TextField` **Greeting message**.
- `M3Segmented` or dropdown **Initial expression** — options from the character's
  known expressions (at minimum `neutral/happy/thinking/surprised/sad/angry`).
- `M3TextField` **Temperature** and **Max tokens** (numeric; empty = default).
- **Portrait images** — a small list mapping `expression → path` sharing
  `photo_emoji_map`:
  - Add/replace via `FileBrowser.qml` (`fsHome`/`fsList`/`fsParent`), which lists
    only images and directories and returns absolute `path`.
  - Each mapping row shows a thumbnail + expression id + remove button.
- Save → `saveCharacter(form, cb)`; Cancel → discard and return.
- Validation errors from the backend (`ValueError` text) show inline.

### 4.6 Settings (`AiSettingsView.qml`)

Sections (use `M3Tile`/rows inside `M3Card`):

- **Appearance:** theme list from `AiBridge.themeIds`; selecting calls the
  backend theme (`themeInfo` for a live preview of `primary`/`surface`), with
  the actual shell appearance remaining driven by `ConfigProvider`/matugen.
- **Assistant:** active character shortcut (→ picker), model/endpoint
  (read from `ConfigProvider`; persisted there, *not* in the backend).
- **Diagnostics:** backend `version`, `ready`/`lastError`, and a **Restart
  bridge** button (`AiBridge.restart()`).

---

## 5. Behavioural requirements

1. **Never block the UI thread.** All backend calls are async over stdio; views
   render from cached properties and react to signals.
2. **Idempotent state.** `AiBridge` is the single source of truth. Widgets must
   not keep divergent copies of chat/character state beyond the visible model.
3. **Graceful degradation.** If the backend never becomes `ready`, show a
   retry affordance and surface `lastError`; the rest of the shell keeps working.
4. **Expression robustness.** Unknown/hallucinated emotions resolve through the
   backend's fallback chain; empty `expressionUrl` always falls back to the emoji.
5. **Unicode-safe.** Names/greetings may be non-ASCII (e.g. Cyrillic) — all text
   is passed through JSON as UTF-8; never assume ASCII in QML.
6. **Persistence split.** Conversations + characters + themes persist in the
   backend; shell appearance/settings persist in `ConfigProvider`
   (`~/.config/material-hyprland/shell.json`). Do not duplicate stores.

---

## 6. Process lifecycle & configuration

- `AiBridge` spawns the backend via:
  `[pythonExe, "-m", "src.ai_girlfriend.ui.ipc_server"]`,
  `workingDirectory = backendRoot`, env `PYTHONPATH=backendRoot`,
  `PYTHONUNBUFFERED=1`.
- **Resolution order:**
  1. `AI_GIRLFRIEND_HOME` (backend checkout path),
  2. `AI_GIRLFRIEND_PYTHON` (interpreter override),
  3. default `~/Projects/AI-girlfriend/AI_girlfriend_chat` with `.venv/bin/python`.
- `scripts/install.sh` is responsible for installing Python + Poetry, running
  `poetry install` for the backend, and exporting `AI_GIRLFRIEND_HOME` /
  `AI_GIRLFRIEND_PYTHON` (via the shell profile) so the bridge can locate it.
- The bridge runs `--demo` only when explicitly requested; production uses the
  real `CompositionRoot` pipeline.

---

## 7. Acceptance checklist

- [ ] Backend starts, `ready` event flips `AiBridge.ready`, header populates.
- [ ] Sending a message shows busy state, then an assistant bubble with text and
      an updated portrait/expression.
- [ ] Switching character rebuilds pipeline, updates header, clears transcript.
- [ ] Creating a character (with at least a name) persists and becomes active.
- [ ] Editing/deleting a custom character works; built-ins cannot be deleted.
- [ ] Image picker browses directories and selects an image into `photo_emoji_map`.
- [ ] History view lists and reopens past conversations.
- [ ] Killing the backend shows an error + retry, and `restart()` recovers.
- [ ] No hardcoded colors/sizes; all styling via `M3Theme`/`M3Tokens`.
- [ ] `qmllint` on new files reports no errors attributable to project code
      (module-import warnings outside Quickshell are expected).

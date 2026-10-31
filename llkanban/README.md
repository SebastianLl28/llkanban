# Kanban

A kanban board for Noctalia, one click away in the bar. Drag cards between
columns, split work into workspaces, break tasks into subtasks and keep the
details in markdown. Everything is stored locally; there are no accounts and no
network access.

## Plugin

| Field | Value |
| --- | --- |
| ID | `sebastianll28/llkanban` |
| Entries | Bar widget: `toggle`; panel: `board` |

## Requirements

No external programs, accounts, network access or compositor-specific features
are required. The plugin needs Noctalia plugin API 38 (Noctalia v5.4.0 or
later), which lets a whole card be dragged and still open on a click.

## Usage

Add the `toggle` widget from Noctalia's widget picker and click it to open or
close the board. Next to its icon the widget shows how many tasks are pending
across all workspaces, meaning not in a closed column. Its tooltip breaks the
number down per workspace, and the number hides at zero. To open the board
from a compositor shortcut, bind:

```sh
noctalia msg panel-toggle sebastianll28/llkanban:board
```

### Board

- Type a title in the top field and press **Enter** to add a task to the first
  column.
- Click a card to open the task. Drag it to another column, or between two
  cards to reorder it.
- A card shows the title on up to three lines, how many subtasks are left and
  an icon when the task has a description.
- Each workspace starts with **To do**, **In progress** and **Done**. Add a
  column with the **+** tile after the last one; the pencil in a column header
  renames it, moves it left or right, or deletes it. The last column cannot be
  deleted.
- Turn on **Closed** in a column's edit controls when its tasks are finished
  or discarded (for example **Done**, **Archived** or **Discarded**). Closed
  columns show a check icon and their tasks do not count as pending. A new
  workspace starts with **Done** closed.

### Workspaces

The row under the title lists the workspaces. Click one to switch to it, **+**
to add one, and the buttons on the right to rename or delete the current one.
The last workspace cannot be deleted.

### Task detail

Opening a task replaces the board with its detail:

- **Title**: the pencil next to it renames the task and the trash deletes it.
- **Move**: a column selector and up/down buttons move or reorder the task
  without dragging.
- **Subtasks**: add them with **Enter**, mark them done with the switch, rename
  or delete them. Subtasks have no subtasks of their own and do not appear in
  the task list.
- **Description**: free text rendered as markdown. **Edit** opens a multiline
  editor and **Preview** shows the rendered result. The text saves itself after
  a short pause, on **Ctrl+Enter**, when leaving the task and when the panel
  closes.

### Task list

The list button in the header shows every task of the current workspace in
board order, with its column and subtask progress. Type to filter by title.
Turn on **All workspaces** to include the other workspaces; opening one of
their tasks switches to that workspace.

### Import and export

The database button in the header opens **Import and export**. Type a path
that is absolute or starts with `~/` (the default is `~/llkanban-export.json`):

- **Export** writes every workspace, with its columns, tasks, subtasks and
  descriptions, to that JSON file. An existing file at that path is replaced.
- **Import** reads such a file and adds its workspaces as new ones. Existing
  workspaces are never changed; an imported workspace whose name is taken gets
  a suffix such as `(2)`. The active workspace stays the same.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `force_delete` | `bool` | `false` | Deletes columns and workspaces together with their tasks. When off, a column or workspace must be empty before it can be deleted. |

Deletion never asks for confirmation.

## Notes

### Storage and side effects

- Data lives in the directory returned by `noctalia.pluginDataDir()`:
  `workspaces.json` holds the workspace list and the active one, and each
  workspace has its own `ws_<id>.json` with columns, tasks, subtasks and
  descriptions.
- Files are written to a temporary file and renamed over the original, so
  closing the shell during a save never leaves a half-written file.
- Data from versions before workspaces existed (`ws_default.json`) is adopted
  as the first workspace and the old file is removed.
- Outside that directory the plugin only touches the path typed in **Import
  and export**, and only when **Export** (writes it) or **Import** (reads it)
  is pressed.
- The plugin makes no network requests, starts no processes and runs no remote
  code.

### Limitations

- The panel is 1000 × 480 px. Noctalia fixes panel sizes in the manifest, so it
  cannot be resized.
- Drag and drop works with the pointer only; use the move controls in the task
  detail from the keyboard.
- The interface is in English only.

## License

MIT

# llkanban

A Noctalia source repository with one plugin: [**Kanban**](llkanban/README.md),
a kanban board with workspaces, custom columns, subtasks and markdown details.

> **Preview.** The `0.x` versions are previews of 1.0. Expect rough edges, and
> please report bugs in the issues.

## Install

Add this repository as a plugin source and enable the plugin:

```sh
noctalia msg plugins source add llkanban git https://github.com/SebastianLl28/llkanban
noctalia msg plugins enable sebastianll28/llkanban
```

Then add the **Kanban** widget to a bar from Noctalia's widget picker. Pull new
versions with `noctalia msg plugins update llkanban`.

## Layout

| Path | Contents |
| --- | --- |
| `catalog.toml` | Index Noctalia reads to list the plugin without cloning |
| `llkanban/` | The plugin: manifest, Luau entries, translations and its own README |

## License

[MIT](LICENSE)

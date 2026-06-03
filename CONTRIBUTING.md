# Contributing to Evolve

Thanks for helping with the project. This document explains how the Luau source is laid out on disk and how it maps into the game via Rojo.

## Folder structure

| Path | Role |
|------|------|
| **`src/server/`** | **Server scripts** — authority, spawning, round logic, data that must not be trusted to the client. Entry: `init.server.luau` (runs as a `Script` under `ServerScriptService.Server`). |
| **`src/client/`** | **Client scripts** — UI, camera, local feedback, input. Entry: `init.client.luau` (runs as a `LocalScript` under `StarterPlayer.StarterPlayerScripts.Client`). |
| **`src/shared/`** | **Shared modules** — code used by both server and client (types, constants, pure helpers). Lives under `ReplicatedStorage.Shared` at runtime so both sides can `require` it. |

Add new `.luau` modules next to the layer they belong to; keep server-only secrets and anti-cheat logic strictly under `src/server/`.

## Rojo project

Paths and instance names are defined in `default.project.json`. If you add top-level services or folders in Studio, update the Rojo tree so filesystem and DataModel stay in sync.

## Style and workflow

- Prefer **Luau** (`.luau`) for new files.
- Match naming and patterns used in existing `init.server.luau` / `init.client.luau` and shared modules.
- Test changes in Studio with `rojo serve` before opening a pull request.

If something in this layout is unclear, open an issue or ask in the project’s usual chat channel.

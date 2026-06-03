# Evolve

A **mope.io**–style evolution game for Roblox: eat food pellets and smaller players to gain points, level up, and at each tier pick one of **three random animals**. Progress through **eight tiers** toward apex predators.

## Biomes

Four biomes, each with its own animal line through **Tier 8** apex animals:

- **Forest**
- **Desert**
- **Arctic**
- **Volcano**

## Game modes

| Mode | Description |
|------|-------------|
| **Endless** | No round timer; grind kills and titles at your own pace. |
| **Ranked** | **15-minute** rolling rounds with a **leaderboard** at the end. |

## Kill titles

Titles unlock through kills, in order:

**Fresh Prey** → **Scavenger** → **Pack Hunter** → **Apex** → **Shadow Predator** → **Void Hunter** → **Extinction Event** → **The Last Predator**

## Skins

Skins are earned from:

- **Chests** (purchased with **coins** or **Robux**)
- **Kill title** milestones
- **Playtime / survival** rewards

Duplicate skins **level up** that skin (**max level 5**).

## Death

On death, players **lose 2 levels** but **keep** kill titles and their skin collection.

## Current status

**Phase 1** — food spawning and the points system are **complete**. Further systems (biomes, modes, progression UI, etc.) are planned or in progress.

---

## Development

This repo is synced with Roblox Studio using [Rojo](https://github.com/rojo-rbx/rojo). See [CONTRIBUTING.md](CONTRIBUTING.md) for where scripts live in the filesystem.

Build a place file:

```bash
rojo build -o Evolve.rbxlx
```

Live sync while editing:

```bash
rojo serve
```

Open the generated `.rbxlx` in Studio, connect the Rojo plugin, and sync. More detail: [Rojo documentation](https://rojo.space/docs).

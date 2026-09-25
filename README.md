# PascalCase Explorer

PascalCase Explorer is a client-side Luau runtime explorer intended for debugging and authorized security testing of Roblox experiences you own or have permission to test.

## Current status

Phase 1 is platform-verified in Roblox. Phase 1.5 replaced the original per-Instance signal model with three global connections plus batched reconciliation. Phase 2 provides a virtualized Explorer GUI, and Phase 2.1 adds core navigation and usability features.

## Phase 2.1 GUI

The normal executor payload opens the Explorer automatically.

Current GUI features:

- Virtualized hierarchy tree with 64 reusable row widgets
- Root displayed as `game`
- Lightweight class/service glyphs
- Expand/collapse controls
- Double-click to expand/collapse
- Double-click a search result to reveal it in the hierarchy
- Press Enter in search to reveal the first result
- Selection auto-scroll
- Draggable and resizable window
- Right-click context menu
  - Copy Name
  - Copy Lua Path
  - Copy ClassName
  - Reveal in Tree
  - Refresh
- Clipboard actions use an isolated optional executor adapter and fail gracefully if the executor does not expose a clipboard function
- Properties panel with Name, ClassName, Parent, child count, attribute count, Archivable, node ID, FullName, and a safe bracketed Lua path
- Live status for tracked Instance count and hierarchy connection count

Example copied Lua path:

```lua
game["SoundService"]["Effects"]["VoidSwitch"]
```

## Scalability architecture

The hierarchy runtime does not attach Name or Ancestry signals to every Instance.

```text
Roblox hierarchy
      │
      ├── DescendantAdded
      ├── DescendantRemoving
      └── RunService.Heartbeat
                 │
                 ▼
        batched reconciliation
        512 nodes/frame default
```

A running hierarchy uses three global connections regardless of whether it tracks hundreds or hundreds of thousands of client-visible Instances.

Runtime statistics are available through:

```lua
local session = _G.__PascalCaseExplorerSession
local stats = session.Hierarchy:GetStats()

print(stats.TrackedInstances)
print(stats.ConnectionCount)
print(stats.PerInstanceConnections)
print(stats.CompletedPasses)
print(stats.LastPassSeconds)
```

## Executor payloads

Successful CI runs produce:

```text
PascalCaseExplorer.luau
PascalCaseExplorer_Phase1Test.luau
PascalCaseExplorer_PerformanceTest.luau
```

The normal runtime payload starts PascalCase and stores its session at:

```lua
_G.__PascalCaseExplorerSession
```

## Build locally

```powershell
rokit install
New-Item -ItemType Directory -Force dist | Out-Null
darklua process executor/entry.luau dist/PascalCaseExplorer.luau -c .darklua.json5
darklua process executor/phase1_test_entry.luau dist/PascalCaseExplorer_Phase1Test.luau -c .darklua.json5
darklua process executor/performance_test_entry.luau dist/PascalCaseExplorer_PerformanceTest.luau -c .darklua.json5
```

## Scope

PascalCase Explorer is for inspection, debugging, replication visibility, and authorized security auditing. It is not intended for bypassing protections in third-party experiences.

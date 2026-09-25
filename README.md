# PascalCase Explorer

PascalCase Explorer is a client-side Luau runtime explorer intended for debugging and authorized security testing of Roblox experiences you own or have permission to test.

## Current status

Phase 1 is platform-verified in Roblox. Phase 1.5 replaced per-Instance hierarchy signals with three global connections plus batched reconciliation. Phase 2 added the virtualized Explorer GUI. Phase 2.1 added navigation and context actions. Phase 2.2 adds deeper property inspection and client-side property editing.

## Phase 2.2 property inspector

The Properties pane now uses a dedicated `PropertyInspector` runtime module instead of hard-coded display rows.

It provides:

- Categorized property groups
- Property filtering
- Editable text fields for supported property types
- Read-only display for unsupported or protected values
- Instance attributes listed in an Attributes section
- Explorer metadata including child count, node ID, FullName, and Lua path
- Graceful write errors when Roblox rejects a property change

Supported editable value types:

```text
string
number
boolean
Color3
Vector2
Vector3
UDim
UDim2
EnumItem
```

Examples:

```text
Transparency        0.5
Anchored            true
Position            10, 5, -2
Color               255, 128, 64
Size                4, 1, 8
Position (GUI)      0.5, -100, 0, 20
Material            SmoothPlastic
```

The catalog includes common properties for BasePart, Humanoid, Sound, GuiObject, text/image UI objects, ScreenGui, Lighting, Camera, Animation, Decal, Texture, ProximityPrompt, ClickDetector, and ValueBase objects. Property availability is checked at runtime, so unavailable members are skipped rather than causing the Explorer to fail.

Property changes are client-side. Roblox replication rules and game scripts may overwrite them, and server-authoritative state is not bypassed.

## Phase 2.1 navigation

The Explorer also includes:

- Root displayed as `game`
- Lightweight class/service glyphs
- Double-click expand/collapse
- Search and reveal-in-tree navigation
- Selection auto-scroll
- Draggable and resizable window
- Right-click context menu
  - Copy Name
  - Copy Lua Path
  - Copy ClassName
  - Reveal in Tree
  - Refresh
- Optional isolated clipboard adapter
- Virtualized hierarchy rows

## Scalability

The hierarchy runtime uses:

```text
DescendantAdded
DescendantRemoving
RunService.Heartbeat
```

instead of attaching signals to every tracked Instance. The tree view uses a reusable row pool, so large client hierarchies do not create one GUI object per tracked Instance.

## Runtime access

The normal bundle stores its session at:

```lua
_G.__PascalCaseExplorerSession
```

Example:

```lua
local session = _G.__PascalCaseExplorerSession
local stats = session.Hierarchy:GetStats()

print(stats.TrackedInstances)
print(stats.ConnectionCount)
print(stats.PerInstanceConnections)
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

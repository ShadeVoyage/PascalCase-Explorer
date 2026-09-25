# PascalCase Explorer

PascalCase Explorer is a client-side Luau runtime explorer intended for debugging and authorized security testing of Roblox experiences you own or have permission to test.

## Current status

Phase 1 is platform-verified in Roblox. Phase 1.5 replaced per-Instance hierarchy signals with three global connections plus batched reconciliation. Phase 2 added the virtualized Explorer GUI. Phase 2.1 added navigation and context actions. Phase 2.2 added deeper property inspection and client-side property editing. Phase 2.3 redesigns the interface as a Roblox Studio-inspired right-docked Explorer and Properties shell.

## Phase 2.5 built-in icon atlas fallback

The live Roblox client blocks the Studio-only class-icon call in normal execution, so PascalCase now has a second image-icon path that requires no security elevation and no executor filesystem APIs.

Icon resolution order:

```text
1. StudioService:GetClassIcon()      when permitted
2. rbxasset://textures/ClassImages.png
   with a built-in class → sprite index map
3. compact text fallback
```

The built-in Roblox `ClassImages.png` sheet uses 16x16 icon cells. PascalCase maps common services and Instance classes to their sprite offsets and renders those cells through the same virtualized `ImageLabel` rows. Unknown top-level services receive a generic service image rather than a letter whenever possible.

This fallback is the reliable live-client path. It uses Roblox's bundled class-image texture, so it does not need HTTP requests, downloaded files, `getcustomasset`, thread-identity changes, or a separately uploaded decal.

## Phase 2.4 Studio class icons

PascalCase now asks Roblox for the class icon metadata used by Studio through `StudioService:GetClassIcon(className)`. When the runtime permits that PluginSecurity API, tree rows render the returned `Image`, `ImageRectOffset`, and `ImageRectSize` directly in a 16x16 `ImageLabel`.

In normal live-game contexts Roblox may reject the Studio-only API. PascalCase handles that safely and falls back to its compact text glyphs instead of failing the Explorer. The icon provider caches successful official lookups by class name so virtualized row reuse does not repeatedly query StudioService.

Because Roblox does not expose the modern Studio icon pack as a normal game asset API, exact current Studio icons in a live executor depend on whether that executor/runtime can legitimately access `StudioService:GetClassIcon`. PascalCase does not alter thread identity or bypass Roblox security to obtain them.

## Phase 2.3 Studio-style shell

The floating PascalCase window has been replaced by a right-docked interface modeled after Roblox Studio's Explorer and Properties workflow.

Current shell behavior:

- Explorer docked to the right side of the client
- Properties panel below Explorer
- Draggable horizontal divider between Explorer and Properties
- Draggable left edge to resize dock width
- Studio-like dark panel/header/search styling
- Explorer header with refresh, collapse-all, and close controls
- Compact 20-pixel virtualized tree rows
- Full-row blue selection highlight and hover feedback
- Search field directly under the Explorer header
- Filter Properties field directly under the Properties header
- Existing search, reveal, context menu, property editing, attributes, and hierarchy synchronization preserved

The interface is still a normal Roblox `ScreenGui`; it imitates Studio's layout but does not use Studio-only docking APIs.

## Phase 2.2 stability hotfix

PascalCase excludes its own `ScreenGui` subtree from `LiveHierarchy`. This prevents the Explorer's property rows and other UI objects from recursively triggering hierarchy rebuilds.

GUI rebuild requests are also coalesced with a short delay while the rebuild lock remains held until rendering finishes. This prevents Roblox's `Maximum re-entrancy depth` failure during heavy client hierarchy activity.

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

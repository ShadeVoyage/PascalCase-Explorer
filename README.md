# PascalCase Explorer

PascalCase Explorer is a client-side Luau runtime explorer intended for debugging and authorized security testing of Roblox experiences you own or have permission to test.

The repository is currently in bootstrap stage. The first goal is a clean, testable development environment before implementing the explorer UI or executor-specific adapters.

## Toolchain

The project pins its developer tools with [Rokit](https://github.com/rojo-rbx/rokit):

- Darklua 0.19.0
- Luau Language Server 1.69.0
- Lune 0.10.5
- Selene 0.31.0
- StyLua 2.5.2

## Windows setup

1. Install Git and Visual Studio Code.
2. Install Rokit in PowerShell:

   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```

3. Clone the repository:

   ```powershell
   git clone https://github.com/ShadeVoyage/PascalCase-Explorer.git
   cd PascalCase-Explorer
   ```

4. Install the pinned project tools:

   ```powershell
   rokit install
   ```

5. Open the repository in VS Code:

   ```powershell
   code .
   ```

6. Install the recommended VS Code extensions when prompted.

## Quality checks

```powershell
stylua --check src tests executor
selene src tests executor
lune run tests/smoke.luau
lune run tests/tree_store.luau
lune run tests/roblox_harness_smoke.luau
```

To apply formatting:

```powershell
stylua src tests executor
```

## Architecture

```text
src/
├── init.luau
├── Version.luau
├── Core/
│   └── TreeStore.luau        Pure explorer hierarchy state
├── Runtime/
│   ├── RobloxSnapshot.luau   Captures the client-visible Instance tree
│   └── LiveHierarchy.luau    Keeps the captured tree synchronized
└── UI/                       Explorer interface (later phase)

executor/
└── entry.luau                Runtime bootstrap used for the single-file build

tests/
├── smoke.luau
├── tree_store.luau
├── roblox_harness_smoke.luau
├── executor_bundle_smoke.luau
└── roblox/
    └── phase1_live_hierarchy.integration.luau

dist/                          Generated locally; ignored by Git
└── PascalCaseExplorer.luau
```

## Phase 1

Phase 1 implements the explorer's hierarchy data foundation.

`RobloxSnapshot.Capture(root)` walks the Roblox hierarchy visible to the current client and mirrors it into `TreeStore`. `LiveHierarchy.Start(root)` builds on that snapshot and keeps the mirror synchronized with the live Roblox hierarchy.

The live synchronizer handles:

- Instances entering the observed hierarchy
- Instances leaving the observed hierarchy
- Instance renames
- Re-parenting inside the observed hierarchy
- Subtree removal
- Instance-to-node and node-to-Instance lookup
- Change notifications for future UI code
- Cleanup through `LiveHierarchy:Destroy()`

Example runtime shape:

```lua
local hierarchy = PascalCaseExplorer.LiveHierarchy.Start(game)

local disconnect = hierarchy:Subscribe(function(change)
	print(change.Kind, change.Id)
end)

local workspaceId = hierarchy:GetId(workspace)

disconnect()
hierarchy:Destroy()
```

The synchronizer re-checks the Instance's current ancestry when hierarchy events fire instead of assuming an event still represents the object's current state. Removal reconciliation is deferred by one task turn so `DescendantRemoving` can be validated against the post-change hierarchy state.

### Roblox integration harness

`tests/roblox/phase1_live_hierarchy.integration.luau` is the Phase 1 runtime test. In a real Roblox client it creates an isolated temporary hierarchy and verifies addition, rename, in-root re-parenting, subtree removal, subtree re-entry, destruction, change notifications, and cleanup.

The harness returns a function that accepts the loaded PascalCase Explorer module:

```lua
local runIntegration = -- load the integration harness in the Roblox test environment
runIntegration(PascalCaseExplorer)
```

A successful Roblox run prints:

```text
PascalCase Explorer Phase 1 Roblox integration test passed
```

GitHub Actions verifies that this Roblox-specific harness parses and loads. It cannot execute Roblox's real `Instance` event engine, so the runtime behavior must still be executed in Roblox before Phase 1 is considered platform-verified.

## Executor build/bootstrap

Darklua bundles the project and its string-based Luau module requires into one executable Luau file. This keeps the core source modular while giving an executor a single payload.

Build it with:

```powershell
New-Item -ItemType Directory -Force dist | Out-Null
darklua process executor/entry.luau dist/PascalCaseExplorer.luau -c .darklua.json5
```

The generated file is:

```text
dist/PascalCaseExplorer.luau
```

Run that generated file only in an experience you own or are authorized to test. In Roblox it starts `LiveHierarchy` at `game` and stores the active session at:

```lua
_G.__PascalCaseExplorerSession
```

The session exposes:

```lua
local session = _G.__PascalCaseExplorerSession

print(session.Version)
print(session.Hierarchy.Tree:GetCount())

session.Stop()
```

Executing the bundle again attempts to destroy the previous hierarchy first, which prevents duplicate live-event subscriptions during repeated development runs.

No executor-specific API such as `getgenv`, HTTP loading, or a protection bypass is required by this bootstrap. Executor-specific capabilities should be added later only behind isolated adapters when a feature actually requires them.

## Continuous integration

GitHub Actions checks formatting, linting, pure-Luau tests, the Roblox integration-harness load, builds the executor bundle, and loads that generated bundle under Lune as a non-Roblox smoke test.

## Scope

Use PascalCase Explorer only in environments you own or are explicitly authorized to test. The project should focus on inspection, debugging, replication visibility, and security auditing rather than bypassing protections in third-party experiences.

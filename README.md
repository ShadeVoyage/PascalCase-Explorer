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
2. Install Rokit in PowerShell.
3. Clone the repository.
4. Run `rokit install`.
5. Open the repository in VS Code.

## Architecture

```text
src/
├── init.luau
├── Version.luau
├── Core/
│   └── TreeStore.luau
├── Runtime/
│   ├── RobloxSnapshot.luau
│   └── LiveHierarchy.luau
└── UI/

executor/
├── entry.luau
└── phase1_test_entry.luau

tests/
├── smoke.luau
├── tree_store.luau
├── roblox_harness_smoke.luau
├── executor_bundle_smoke.luau
├── phase1_executor_bundle_smoke.luau
└── roblox/
    └── phase1_live_hierarchy.integration.luau

dist/
├── PascalCaseExplorer.luau
└── PascalCaseExplorer_Phase1Test.luau
```

## Phase 1

Phase 1 implements the explorer's hierarchy data foundation. `RobloxSnapshot.Capture(root)` walks the client-visible Roblox hierarchy and mirrors it into `TreeStore`. `LiveHierarchy.Start(root)` keeps that mirror synchronized.

## Build the executor scripts

```powershell
rokit install
New-Item -ItemType Directory -Force dist | Out-Null
darklua process executor/entry.luau dist/PascalCaseExplorer.luau -c .darklua.json5
darklua process executor/phase1_test_entry.luau dist/PascalCaseExplorer_Phase1Test.luau -c .darklua.json5
```

The normal runtime payload is `dist/PascalCaseExplorer.luau`.

The one-shot Phase 1 verification payload is `dist/PascalCaseExplorer_Phase1Test.luau`.

GitHub Actions also builds both files and publishes them together as the `pascalcase-executor-bundles` workflow artifact for successful CI runs.

## Run the Phase 1 test payload

Use `PascalCaseExplorer_Phase1Test.luau` in an experience you own or are explicitly authorized to test. Paste the complete generated file into the executor's script editor and run it once.

Expected output:

```text
[PascalCase Explorer] Running Phase 1 Roblox integration test...
PascalCase Explorer Phase 1 Roblox integration test passed
[PascalCase Explorer] PHASE 1 TEST: PASS
```

If an assertion fails, the payload prints `[PascalCase Explorer] PHASE 1 TEST: FAIL` followed by the specific failed condition.

The integration test creates an isolated temporary Folder in Workspace, exercises additions, renames, re-parenting, subtree removal/re-entry, destruction, change notifications, and cleanup, then removes its test objects.

## Run the normal runtime payload

`PascalCaseExplorer.luau` starts `LiveHierarchy` at `game` and stores the active development session at `_G.__PascalCaseExplorerSession`.

```lua
local session = _G.__PascalCaseExplorerSession
print(session.Version)
print(session.Hierarchy.Tree:GetCount())
session.Stop()
```

No executor-specific API such as `getgenv`, HTTP loading, filesystem access, or protection bypass is required by the current bootstrap.

## Continuous integration

GitHub Actions checks formatting, linting, pure-Luau tests, the Roblox test harness load, both Darklua builds, and both generated bundles under Lune. Successful runs upload the ready-to-run bundles as a workflow artifact for 14 days.

GitHub Actions cannot reproduce Roblox's real `Instance` event engine, so the Phase 1 test payload must still be executed in Roblox before Phase 1 is considered platform-verified.

## Scope

Use PascalCase Explorer only in environments you own or are explicitly authorized to test. The project should focus on inspection, debugging, replication visibility, and security auditing rather than bypassing protections in third-party experiences.

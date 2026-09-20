# PascalCase Explorer

PascalCase Explorer is a client-side Luau runtime explorer intended for debugging and authorized security testing of Roblox experiences you own or have permission to test.

## Current status

Phase 1 is platform-verified in Roblox. Phase 1.5 replaces the original per-Instance event model with a scalable global-event plus batched-reconciliation architecture before the Explorer GUI is built.

## Toolchain

The project pins its developer tools with Rokit:

- Darklua 0.19.0
- Luau Language Server 1.69.0
- Lune 0.10.5
- Selene 0.31.0
- StyLua 2.5.2

## Phase 1.5 scalability architecture

The initial Phase 1 runtime attached Name and Ancestry signals to every tracked Instance. At 70,000 client-visible Instances that could exceed 100,000 event connections.

Phase 1.5 removes all per-Instance connections.

```text
Roblox hierarchy
      │
      ├── DescendantAdded ─────┐
      ├── DescendantRemoving ──┼── immediate add/remove handling
      │                        │
      └── RunService.Heartbeat ┘
                 │
                 ▼
        batched reconciliation
        512 nodes/frame default
                 │
          ┌──────┴──────┐
          │             │
       renames        moves
```

A running hierarchy now uses exactly three global connections regardless of whether it tracks 100 Instances or 70,000.

Renames and in-root reparenting are detected by a rolling background scan. New and removed descendants remain event-driven. Future UI code can call `RefreshObject()` or `RefreshId()` to immediately reconcile a selected or visible node instead of waiting for its background scan turn.

Runtime statistics are available through:

```lua
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

The Phase 1 test payload verifies hierarchy correctness.

The Phase 1.5 performance payload measures the real client workload and verifies that PascalCase is using zero per-Instance connections:

```text
[PascalCase Explorer] Starting Phase 1.5 scalability test...
[PascalCase Explorer] Tracked instances: ...
[PascalCase Explorer] Global connections: 3
[PascalCase Explorer] Per-instance connections: 0
[PascalCase Explorer] Reconcile batch size: 512
[PascalCase Explorer] Completed scan passes: ...
[PascalCase Explorer] Last full scan: ... seconds
[PascalCase Explorer] PHASE 1.5 SCALABILITY TEST: PASS
```

Use the payloads only in experiences you own or are explicitly authorized to test.

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

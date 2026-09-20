# PascalCase Explorer

PascalCase Explorer is a client-side Luau runtime explorer intended for debugging and authorized security testing of Roblox experiences you own or have permission to test.

The repository is currently in bootstrap stage. The first goal is a clean, testable development environment before implementing the explorer UI or executor-specific adapters.

## Toolchain

The project pins its developer tools with [Rokit](https://github.com/rojo-rbx/rokit):

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
stylua --check src tests
selene src tests
lune run tests/smoke.luau
```

To apply formatting:

```powershell
stylua src tests
```

## Initial architecture

```text
src/
├── init.luau           Project entry module
├── Version.luau        Project metadata
├── Core/               Pure Luau state and explorer logic
├── Runtime/            Roblox/executor capability adapters
└── UI/                 Explorer interface

tests/
└── smoke.luau          Toolchain smoke test
```

Keep executor-specific APIs isolated under `src/Runtime/`. Core tree/state/search logic should remain ordinary Luau where possible so it can be linted and tested independently.

A single-file runtime build/bundling step is intentionally not selected yet. That decision should be made after the target executor interface is defined instead of coupling the project to one executor prematurely.

## Continuous integration

GitHub Actions checks formatting, linting, and the smoke test on pushes and pull requests.

## Scope

Use PascalCase Explorer only in environments you own or are explicitly authorized to test. The project should focus on inspection, debugging, replication visibility, and security auditing rather than bypassing protections in third-party experiences.

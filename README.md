# Advanced Modular Combat System

This is a high-performance, fully modular combat framework built for Roblox Studio using Rojo. This system splits client-side inputs, server-side validation, and shared data modules into a clean, scalable architecture.

## System Features & Architecture

Based on my project structure, the codebase is split into three main layers:

### Client Side (`src/client`)
Handles responsive local player inputs, visual feedback, and user interface rendering:
- **CombatHandler:** Captures and processes local attack inputs and combo execution
- **BlockReplicator:** Manages local shield/blocking states and triggers smooth defensive animations
- **CameraShakeClient:** Adds dynamic, high-impact camera shake effects during heavy hits
- **ComboPopup:** Renders client-side damage numbers or combo-streak popups above targets
- **Shiftlock:** A customized built-in shiftlock system optimized 
- **ClientRagdoll & ReplicationClient:** Manages smooth local physics rendering and visual syncing

### Server Side (`src/server`)
Enforces server-authoritative logic, database persistency, and anti-cheat validation:
- **CombatServer & BlockServer:** Core state engines that process hit registration damage mitigation, parry windows, and posture breaks
- **DataHandler:** Saves player progress, combat stats, and unlocked fighting styles
- **BanManager:** Integrates automated safety loops to ban exploiters and a complete Ban Manager

### Shared Assets & Data (`src/shared`)
Central repository for assets, configurations, and cross-boundary network channels:
- **modules/FightingStyle:** The core object-oriented framework that manages player combat states, weapon combo indexing, and procedural motor-decoupling for server side character ragdolling
- **modules/StylesData & KeybindsData:** Configuration files to tweak combo timings, damage scales, and customizable user keybind structures
- **vfx/** Includes standalone Roblox model assets (`.rbxm`) for fast runtime rendering:
- NOTE: I DID NOT CREATE ANY OF THE VFX
  - `hit.rbxm` (Impact burst effects)
  - `block.rbxm` (Shield spark effects)
  - `blockBreak.rbxm` (Posture break indicators)
  - `dizzy.rbxm` (Star moving indicators)

## Getting Started

### Building the Project
Compile the directory structure directly into a Roblox place file (`.rbxlx`) from your terminal:
```bash
rojo build -o "advanced_combat_system.rbxlx"
```

### Living File Sync
Open the compiled place file in Roblox Studio and initialize the live sync server to edit code in your external editor:
```bash
rojo serve
```

## OOP Ragdoll Engine
The `FightingStyle` module handles a procedural `BallSocketConstraint` bone decoupling sequence over the server network pipeline. It overrides standard internal humanoid active state values, automatically maps custom limits sourced from `StylesData`, drops systemic dizziness indicators via `DizzyVFX`, and cleanly manages physics cleanup handling upon token recovery bounds.

## License
This combat framework is distributed under the MIT License.

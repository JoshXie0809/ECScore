# ECScore

ECScore is a performance-oriented ECS (Entity Component System) library in Swift, with an EnTT-style query model and bitmask-accelerated iteration.

## Highlights

- Sparse-set based storage with segmented layout.
- Fast view/query execution using block/page/slot bitmasks.
- `with` / `withTag` / `withoutTag` filtering for ECS queries.
- Type-safe platform lifecycle via `Raw -> Validated -> Proof` flow.
- Swift macros for ergonomics and proxy performance (`@Component`, `@FastProxy`).
- Built-in stress workload (`Game7Systems`) and benchmarks.

## Project Structure

- `Sources/ECScore`: ECS core library.
- `Sources/ECScoreMacros`: Swift macro implementations.
- `Sources/Game7Systems`: executable workload and performance scenario.
- `Tests`: correctness, validation, storage, and query tests.
- `Benchmark`: benchmark outputs and experiment data.

## Requirements

- Swift 6.2+
- macOS 15+ (for declared platform in `Package.swift`) or Linux

## Quick Start

### 1. Build

```bash
swift build -c release
```

### 2. Run Tests

```bash
swift test -c release
```

Run a focused test:

```bash
swift test -c release --filter intersectionTest
```

### 3. Run Demo Workload

```bash
swift run -c release Game7Systems
```

## Core Usage

### Boot platform

```swift
let _base = BasePlatform()
let registry = RegistryPlatform()
let entities = EntityPlatForm_Ver0()
_base.boot(registry: registry, entities: entities)

var pf = Raw(value: _base).upgrade(Platform_Facts.self)
precondition(validate(validated: &pf, .handshake))
guard case let .success(base) = pf.certify(Proof_Handshake.self) else {
    fatalError("platform handshake failed")
}
```

### Register/interop component types

```swift
let tokens = interop(base, PositionComponent.self, VelocityComponent.self)
```

### Query with view

```swift
view(base: base, with: tokens) { _taskId, pos, vel in
    _ = _taskId
    pos.x += vel.vx
    pos.y += vel.vy
}
```

### Query with include/exclude tags

```swift
view(base: base, with: (), withTag: includeTokens, withoutTag: excludeTokens) { _ in
    // matched entity
}
```

## Performance Notes

- Query planning and execution are separated (`createViewPlans` + `executeViewPlans`).
- Iteration is driven by set bits (`trailingZeroBitCount`, `mask &= mask - 1`).
- Dense/sparse segment behavior is tuned with adaptive planning logic.

## Macros

- `@FastProxy`: generate pointer-based proxy members for faster component access.
- `#hs_fnv1a64("...")`: compile-time FNV-1a 64-bit hash.

## Current Status

This project is actively performance-tuned and includes some experimental/legacy code paths (`OldCode/`). The primary runtime path is under `Platform/Entt-mode` and `SparseSetDataContainer`.

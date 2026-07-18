# ADR 0003: Phase 2 state, unique autosave, and settings ownership

## Status

Accepted.

## Decision

Phase 2 removes the runtime save-slot concept. Game state is persisted through one validated autosave envelope under `user://saves`, with temporary-write, reread validation, backup rotation, and atomic replacement. Settings are independent validated data under `user://settings.json`; display mode is one of `windowed`, `borderless`, or `fullscreen`.

The UI exposes new-game and continue intents only. Save/load page and manual slot selection are not part of the Phase 2 contract.

## Consequences

Save and settings repositories remain RefCounted domain-boundary services and are reached through applications. Existing saves are intentionally incompatible with the new schema; no compatibility slot migration is retained.

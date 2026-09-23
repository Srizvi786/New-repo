# Multiplayer — Dustline Strike (design, not yet implemented)

Offline-first. Bots (M7) + local match sim (M8) come before any networking. No fake "multiplayer" UI ships.

## Authority plan (M11)

- Server-authoritative: movement validation, damage, loot pickup, zone ticks, match timer, winner.
- Client: prediction for local player movement + camera + firing FX; reconciliation on snapshot.
- Transports considered (free first): Godot `ENetMultiplayerPeer` (no server cost, LAN/test), then `WebSocketMultiplayerPeer` or Nakama/Edgegap free tier only with approval. No paid backend without explicit sign-off.

## State splits (already in code interfaces)

- `Player.get_state_dict()` / `apply_state_dict()` — pos, vel, crouch, health stub, weapon id, aim.
- `WeaponView.get_state_dict()` — mag, reserve, cooldown, reloading.
- `MatchManager` (stub `src/match/MatchManager.gd`) — phase, timer, alive count, zone index.
- World seed + loot table hash exchanged at match start.

## Anti-cheat minimum (later)

Server clamps speed/teleport, fire-rate check, line-of-sight spot check. No client-trusted damage.

## What is NOT claimed

No netcode runs in M1. Lobby UI says "OFFLINE — bots only" until a real peer + dedicated server test passes.

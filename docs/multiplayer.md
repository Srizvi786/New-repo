# Multiplayer — Dustline Strike (M11 LAN baseline implemented)

Offline-first default. Menu shows OFFLINE until HOST/JOIN succeeds.

## What works (M11)

- ENet host/join over LAN/loopback (`NetworkManager`, port 7777, ≤12 peers).
- Host plays the full match (bots + zone + loot); clients connect and play with
  local prediction (instant feel) + 10 Hz state sync to the server.
- **Server-authoritative damage**: clients send `request_damage` RPCs; the
  server enforces 20 req/s per attacker, 120 dmg and 350 m sanity caps, then
  applies. Clients never apply damage locally; HP arrives via snapshots.
- **Anti-teleport**: server ignores client position jumps over 12 m/update.
- **Snapshots** (10 Hz, unreliable): host/bot/proxy transforms + HP + anim,
  zone center/radius, match timer. Kill feed relayed to clients.
- **Deterministic world**: fixed loot/district seeds, so client and server
  simulate the same arena; only dynamic state is synced.

## Limits (honest)

- No public backend, no matchmaking, no NAT traversal — same-WiFi or
  loopback (`127.0.0.1`) only. Loot pickups are locally simulated and can
  desync between peers. Client prediction has no reconciliation beyond HP
  sync. These are M11-baseline tradeoffs, not a full netcode.

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

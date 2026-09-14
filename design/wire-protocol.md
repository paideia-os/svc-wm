# svc-wm wire protocol -- R102-WM-v0 (R102.M1-002, #2)

Frozen at v0.5.0. Any renumbering or record-layout change ships as
`R102-WM-v1` alongside a `protocol.version` bump in `caps.decl` and a
corresponding minor version bump in `CHANGELOG.md`.

## 1. Transport

Every message rides the generic kernel IPC substrate
(`design/ipc/userspace-server-substrate.md` in the paideia-os monorepo,
§4.1-4.3): `sys_ipc_send` (sysno 42) / `sys_ipc_recv` (sysno 40) /
`sys_ipc_reply` (sysno 41) against a `KIND_IPC_ENDPOINT` cap, resolved
by name via `sys_svc_lookup` (sysno 43). The generic substrate's own
8-byte header (`op:u8, ver:u8, reply_endpoint_id:u16 LE, payload_len:u32
LE`) is unchanged; svc-wm additionally pins every payload it sends or
accepts to a **fixed 56-byte shape**, so every svc-wm frame -- request
or reply -- is exactly **64 bytes** end to end (8-byte generic header +
56-byte svc-wm payload), regardless of message type. Fields a given
message does not use are reserved and MUST be zero on the wire.

```
+------+------+-----------------+---------------------+----------------------+
|  op  |  ver | reply_ep_id (u16)|   payload_len (u32) |   payload (56 B)    |
+------+------+-----------------+---------------------+----------------------+
   +0     +1        +2..+3              +4..+7                +8..+63
```

`reply_endpoint_id = 0` selects the legacy same-endpoint reply semantic
(userspace-server-substrate.md §4.4 option A, "reply-on-source"). The
dual-endpoint upgrade (a non-zero client-minted reply endpoint) is
deferred to a future milestone if the broker's rights_gate for `svc.wm`
turns out to be send-only for a given caller class -- see
`src/main.pdx`'s module header for the same-endpoint assumption this
v0 wire protocol currently makes for the compositor round trip.

## 2. Message codes

Ordinals below are byte-for-byte synchronized with `caps.decl`'s
`request.*` / `reply.*` lines.

| Code | Name                | Direction        | §   |
|------|---------------------|-------------------|-----|
| 0x01 | REGISTER_CLIENT     | client -> svc.wm  | 2.1 |
| 0x02 | SURFACE_ATTACH      | client -> svc.wm  | 2.2 |
| 0x03 | SURFACE_DETACH      | client -> svc.wm  | 2.3 |
| 0x04 | FOCUS_QUERY         | client -> svc.wm  | 2.4 |
| 0x05 | FOCUS_SET           | client -> svc.wm  | 2.5 |
| 0x06 | TILE_QUERY          | client -> svc.wm  | 2.6 |
| 0x07 | TILE_SET            | client -> svc.wm  | 2.7 |
| 0x08 | ALT_TAB             | client -> svc.wm  | 2.8 |
| 0x09 | ALT_F4              | client -> svc.wm  | 2.9 |
| 0x0A | ALT_SPACE_PALETTE   | client -> svc.wm  | 2.10|
| 0x0B | PING                | client -> svc.wm  | 2.11|
| 0x0C | GET_STATE           | client -> svc.wm  | 2.12|
| 0x81 | REGISTER_OK         | reply (0x01\|0x80)| 2.1 |
| op\|0x80 | (generic OK)    | reply             | -   |
| 0xFF | ERROR               | reply             | -   |

`REGISTER_CLIENT` is the one dual-use shape in this table: svc-wm's own
`src/main.pdx` sends the identical 64-byte frame *outbound* to
`svc.compositor` at connect time (R102.M1-003, #3), and apps send the
same frame *inbound* to `svc.wm` to register as a window client. Both
directions share this one wire shape.

### 2.1 REGISTER_CLIENT (0x01) / REGISTER_OK (0x81)

Request payload:

| Offset | Size | Field         | Notes                                  |
|--------|------|---------------|------------------------------------------|
| 0      | 8    | client_pid    | `sys_getpid` (sysno 39) result           |
| 8      | 16   | client_name   | ASCII, NUL-padded                        |
| 24     | 32   | reserved      | MUST be zero                             |

Reply payload: all 56 bytes reserved/zero at v0.5.0 (the `op == 0x81`
byte alone is the acceptance signal; a `client_id` assignment field is
a candidate for a future non-zero-reserved revision).

### 2.2 SURFACE_ATTACH (0x02)

| Offset | Size | Field       | Notes                              |
|--------|------|-------------|--------------------------------------|
| 0      | 8    | surface_id  | KIND_SURFACE id (compositor-minted)  |
| 8      | 4    | hint_x      | i32, geometry hint (advisory only -- tiling policy recomputes the authoritative geometry, §src/tiling.pdx) |
| 12     | 4    | hint_y      | i32                                   |
| 16     | 4    | hint_w      | u32                                   |
| 20     | 4    | hint_h      | u32                                   |
| 24     | 32   | reserved    | MUST be zero                          |

### 2.3 SURFACE_DETACH (0x03)

| Offset | Size | Field       |
|--------|------|-------------|
| 0      | 8    | surface_id  |
| 8      | 48   | reserved    |

### 2.4 FOCUS_QUERY (0x04)

Request: all 56 bytes reserved. Reply:

| Offset | Size | Field              |
|--------|------|--------------------|
| 0      | 8    | focused_surface_id | 0 = no surface focused |
| 8      | 48   | reserved           |

### 2.5 FOCUS_SET (0x05)

| Offset | Size | Field       |
|--------|------|-------------|
| 0      | 8    | surface_id  | target to focus |
| 8      | 48   | reserved    |

### 2.6 TILE_QUERY (0x06)

Request (iterator cursor):

| Offset | Size | Field        |
|--------|------|--------------|
| 0      | 4    | cursor_index | 0-based column index requested |
| 4      | 52   | reserved     |

Reply (one row per call):

| Offset | Size | Field        |
|--------|------|--------------|
| 0      | 8    | surface_id   |
| 8      | 4    | geom_x       | i32 |
| 12     | 4    | geom_y       | i32 |
| 16     | 4    | geom_w       | u32 |
| 20     | 4    | geom_h       | u32 |
| 24     | 4    | column_count | total attached count at query time |
| 28     | 28   | reserved     |

### 2.7 TILE_SET (0x07)

| Offset | Size | Field        | Notes |
|--------|------|--------------|-------|
| 0      | 4    | column_count | 0 = auto (defer to tiling policy default) |
| 4      | 52   | reserved     |

### 2.8 ALT_TAB (0x08)

| Offset | Size | Field     | Notes |
|--------|------|-----------|-------|
| 0      | 4    | direction | i32: +1 forward, -1 backward |
| 4      | 52   | reserved  |

### 2.9 ALT_F4 (0x09)

| Offset | Size | Field             | Notes |
|--------|------|-------------------|-------|
| 0      | 8    | target_surface_id | 0 = currently focused |
| 8      | 48   | reserved          |

### 2.10 ALT_SPACE_PALETTE (0x0A)

| Offset | Size | Field         | Notes |
|--------|------|---------------|-------|
| 0      | 4    | command_index | 0 = open palette; 1..3 = select one of the M3 3-command menu |
| 4      | 52   | reserved      |

### 2.11 PING (0x0B)

| Offset | Size | Field | Notes |
|--------|------|-------|-------|
| 0      | 8    | nonce | echoed back verbatim in the reply's identical offset |
| 8      | 48   | reserved |

### 2.12 GET_STATE (0x0C)

Request: all 56 bytes reserved. Reply:

| Offset | Size | Field               |
|--------|------|---------------------|
| 0      | 4    | client_count        |
| 4      | 4    | surface_count       |
| 8      | 8    | focused_surface_id  |
| 16     | 4    | column_count        |
| 20     | 36   | reserved            |

## 3. Outbound requests svc-wm issues (not part of this service's own
inbound protocol, listed for cross-reference)

svc-wm rides two ordinals already frozen by `svc-compositor`'s own
`caps.decl` (v1.1.0) on the `svc.compositor.wm` control endpoint:

- **`WM_PLACE_WINDOW = 0x10`** -- carries svc-wm's `SURFACE_MOVE`
  policy directive (`src/tiling.pdx`): `surface_id:u64, x:u64, y:u64,
  w:u64, h:u64`, padded to the same 56-byte payload shape.
- **`WM_SET_FOCUS = 0x11`** -- carries svc-wm's focus-outline decoration
  directive (`src/decoration.pdx`): `surface_id:u64, border_rgb:u64,
  border_width_px:u64`, padded to 56 bytes. `border_width_px = 0`
  un-decorates; `border_width_px = 2` with `border_rgb = 0x00A0FF`
  decorates.
- **`WM_CLOSE_WINDOW = 0x12`** -- carries svc-wm's Alt+F4 close directive
  (`src/tiling.pdx`, `tiling_focus_close`, R102.M2-003 #6):
  `surface_id:u64`, padded to 56 bytes. Unlike the two ordinals above,
  this one is **svc-wm's OWN forward declaration**, not yet frozen in
  svc-compositor's `caps.decl` (v1.1.0 there declares only
  `0x01/0x02/0x10/0x11/0x20..0x23`). The frame ships at the real wire
  shape today so no further svc-wm change is needed once the peer
  freezes it; see `src/tiling.pdx`'s module header "Wave VV addendum"
  for the full documented-risk rationale.
- **`WM_BLIT = 0x13`** -- carries svc-wm's command-palette label draw
  directive (`src/palette.pdx`, `palette_open`, R102.M3-002 #8):
  `surface_id:u64, row_index:u64, name:[u8;40]`, exactly 56 bytes. Like
  `WM_CLOSE_WINDOW`, this is **svc-wm's OWN forward declaration**, not
  yet frozen in svc-compositor's `caps.decl` (v1.2.0 there declares only
  `0x01/0x02/0x10/0x11/0x20..0x23`); see `src/palette.pdx`'s module
  header "Forward-declared ordinals".

`WM_PLACE_WINDOW` and `WM_SET_FOCUS` are NOT svc-wm's own frozen
ordinals (they belong to svc-compositor's protocol) and are not
re-declared in this repo's `caps.decl`; `WM_CLOSE_WINDOW`/`WM_BLIT` are
listed here for audit-trail purposes even though both are svc-wm's own
not-yet-frozen proposals, since they ride the same `svc.compositor.wm`
control endpoint.

## 4. Milestone provenance

- M1-001 (#1): repo scaffold.
- M1-002 (#2): this document + the `request.*`/`reply.*` lines in
  `caps.decl`.
- M1-003 (#3): `src/main.pdx` REGISTER_CLIENT round trip against
  `svc.compositor`.
- M2-001 (#4): `src/tiling.pdx` SURFACE_MOVE emission.
- M2-002 (#5): `src/decoration.pdx` WM_SET_FOCUS decoration emission.
- M2-003 (#6): `src/main.pdx` Alt+Tab/Alt+F4 dispatcher;
  `src/tiling.pdx` `tiling_focus_advance`/`tiling_focus_close` +
  forward-declared `WM_CLOSE_WINDOW` emission.
- M3-001 (#7): `src/focus.pdx` real `KIND_INPUT_FOCUS` mint
  (`sys_cap_mint`, floor-only sysno 5 pending the documented kernel
  arity-mismatch fix).
- M3-002 (#8): `src/palette.pdx` Alt+Space command palette; forward-
  declared `WM_BLIT = 0x13` emission.
- M4-001..M4-003 (#9, #10, #11): `tests/svc_wm_tile_smoke.pdx`,
  `tests/svc_wm_focus_cycle_smoke.pdx`, `tests/svc_wm_palette_smoke.pdx`.
- M5-001 (#12): signed 1.0.0 release.

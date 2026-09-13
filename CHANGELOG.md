# svc-wm — CHANGELOG

## 0.6.0 — 2026-09-13 (Wave VV: M2-003 Alt+Tab/Alt+F4 dispatch, M3-001 real KIND_INPUT_FOCUS mint)

**Minor bump closing the two-issue Wave VV cohort (#6, #7):** the last
M2 item (Alt+Tab focus cycling + Alt+F4 close) and the first M3 item
(real `KIND_INPUT_FOCUS` capability mint, retiring the `KIND_INPUT_EVENT`
placeholder).

### Added

- **`src/main.pdx`** — R102.M2-003 (#6). `Main::main_dispatch(op)`: the
  decoded-request dispatcher STATUS.md flagged as missing. `ALT_TAB`
  (0x08) advances focus via `Tiling::tiling_focus_advance`, then updates
  the decoration outline (`Decoration::decoration_on_focus_change`) and
  mints a fresh `KIND_INPUT_FOCUS` (`Focus::focus_mint`) for the newly
  focused surface; `ALT_F4` (0x09) closes the focused surface via
  `Tiling::tiling_focus_close`. Any other op returns
  `SWM_MAIN_DISPATCH_UNHANDLED`. Wiring an actual `sys_ipc_recv` server
  loop on `svc.wm`'s own endpoint that feeds this dispatcher remains
  open (documented in the module header). Closes #6.
- **`src/tiling.pdx`** — R102.M2-003 (#6). `tiling_focus_advance`
  (division-free modulo advance over the existing dense
  `swm_tile_ids`/`swm_tile_count` pair) and `tiling_focus_close` (sends
  a forward-declared `WM_CLOSE_WINDOW = 0x12` directive to
  `svc.compositor.wm`, then detaches locally and re-emits tile geometry
  for the survivors via `tiling_emit_moves`). `WM_CLOSE_WINDOW` is
  **NOT yet frozen** in svc-compositor's own `caps.decl` (v1.1.0 there
  declares only `0x01/0x02/0x10/0x11/0x20..0x23`) — svc-wm ships the
  real frame today at the documented-risk posture `src/main.pdx`'s own
  module header already established for the same-endpoint reply
  assumption. Closes #6 alongside `src/main.pdx`.
- **`src/focus.pdx`** — R102.M3-001 (#7). New `Focus` module:
  `focus_mint(surface_id)` issues a real `sys_cap_mint` (sysno 5) call
  in the kernel's actual `(kind, target_ptr, rights)` shape (not the
  undefined §C descriptor-pointer spec), publishing the minted slot to
  `swm_focus_cap_slot`. Floor-only today: sysno 5 is ENOSYS at HEAD per
  the documented kernel arity-mismatch gap
  (design/audit/entries/r13-m5-003-syscall-table.md) — the call site is
  real, not a stub, and starts minting for real with zero source
  changes once the kernel lands its handler. Retires the
  `KIND_INPUT_EVENT` placeholder: `caps.decl` now declares
  `KIND_INPUT_FOCUS` directly (STATUS.md's "naming risk" note,
  resolved). The numeric ordinal (`0x1BA`) stays a locally-declared
  placeholder pending the authoritative R101 freeze. Closes #7.

### Changed

- **`caps.decl`** — `KIND_INPUT_EVENT` -> `KIND_INPUT_FOCUS` (naming
  risk resolution, #7); outbound-ordinal audit-trail block gains the
  `WM_CLOSE_WINDOW = 0x12` forward declaration (#6).
- **`design/wire-protocol.md`** — §3 documents `WM_CLOSE_WINDOW = 0x12`
  and its not-yet-frozen-upstream posture; §4 milestone provenance gains
  M2-003 (#6) and M3-001 (#7).
- **`STATUS.md`** — M2-003 and M3-001 marked landed; "Naming risk"
  section marked resolved; "What v0.6.0 does NOT ship" replaces the
  v0.5.0 list with the three items still open (server loop wiring,
  `WM_CLOSE_WINDOW` freeze, `sys_cap_mint` ENOSYS).
- **`README.md`** — milestone/scaffolding notes updated for the v0.6.0
  landing.
- **`manifest.pdxsig`** — artifact set gains `src/focus.pdx`;
  `package-version`/`package-release` bumped.

Closes paideia-os/svc-wm#6. Closes paideia-os/svc-wm#7.

## 0.5.0 — 2026-09-13 (Wave FF: M1 scaffold + wire freeze + connect/register, M2 tiling + decoration)

**Minor bump from an unversioned two-file scaffold to a five-issue M1/M2
close.** Lands the full M1 milestone (repo scaffold, `caps.decl`, frozen
wire protocol, real connect-to-compositor + register) and the full M2
milestone (fixed-column vertical tiling policy, focus outline
decoration) in one tag.

### Added

- **`caps.decl`** — R102.M1-002 (#2). Root-level plaintext capability
  manifest. `service.name = svc.wm`, `protocol.version = R102-WM-v0`,
  the `svc.wm` registered endpoint, four held cap kinds (`KIND_USER`,
  `KIND_IPC_ENDPOINT`, `KIND_SURFACE` [referenced, not minted],
  `KIND_INPUT_EVENT` [forward-compat placeholder]), the 12 frozen
  inbound request ordinals (`REGISTER_CLIENT=0x01` ..
  `GET_STATE=0x0C`), and the `REGISTER_OK=0x81` / `ERROR=0xFF` sentinel
  replies. Closes #2 alongside `design/wire-protocol.md`.
- **`design/wire-protocol.md`** — R102.M1-002 (#2). Full 64-byte
  fixed-frame layout (8-byte generic header + 56-byte svc-wm payload)
  for all 12 message shapes, plus the two outbound ordinals svc-wm
  rides on svc-compositor's own frozen protocol
  (`WM_PLACE_WINDOW=0x10` for `SURFACE_MOVE`,
  `WM_SET_FOCUS=0x11` for the decoration directive). Closes #2.
- **`src/main.pdx`** — R102.M1-003 (#3). `Main` module, real body (not
  a deferred stub — `sys_svc_lookup`/`sys_ipc_send`/`sys_ipc_recv` are
  all live in the kernel at this wave): looks up `svc.compositor`,
  sends a `REGISTER_CLIENT` frame (client_pid via `sys_getpid`,
  16-byte client_name), and awaits the `REGISTER_OK` reply on the same
  endpoint. Same-endpoint reply assumption documented in the module
  header pending live multi-process verification. Closes #3.
- **`src/tiling.pdx`** — R102.M2-001 (#4). `Tiling` module: dense
  packed-array `tiling_attach`/`tiling_detach` (up to 8 surfaces,
  swap-remove on detach), `tiling_divide` (bounded repeated
  subtraction — paideia-as exposes no `div`/`idiv`), `tiling_recompute`
  (pure fixed-column geometry pass over a 1920x1080 stub viewport, no
  multiplication — running-offset accumulation), and
  `tiling_emit_moves` (real `SURFACE_MOVE` emission to
  `svc.compositor.wm` over the frozen `WM_PLACE_WINDOW` ordinal).
  Closes #4.
- **`src/decoration.pdx`** — R102.M2-002 (#5). `Decoration` module:
  `decoration_on_focus_change` un-decorates the previously-focused
  surface (`border_width_px=0`) then decorates the newly-focused one
  (RGB `0x00A0FF`, 2px) via `decoration_send`, riding the frozen
  `WM_SET_FOCUS` ordinal. No-op guard when the new focus equals the
  current one (no IPC issued). Closes #5.
- **`tests/probe_scaffold.pdx`** — fingerprint witness for #1.
  Publishes `svc-wm scaffold ok\n` (19 bytes).
- **`tests/probe_wire_protocol.pdx`** — fingerprint witness for #2.
  Publishes `svc-wm wire-protocol frozen ok\n` (31 bytes).
- **`tests/probe_register.pdx`** — fingerprint witness for #3
  (deferred live round-trip — needs a running `svc.compositor`, out of
  scope for this repo's single-process smoke). Publishes
  `svc-wm register-client wired ok\n` (32 bytes).
- **`tests/probe_tiling.pdx`** — REAL assertion witness for #4: attach
  four surfaces, verify 480px-column geometry at 1920px viewport width,
  detach one, verify the swap-remove packs correctly. Publishes
  `svc-wm tiling policy ok\n` (24 bytes) only if every assertion holds.
- **`tests/probe_decoration.pdx`** — REAL assertion witness for #5: the
  no-IPC no-op guard path (refocusing the fresh-boot default id 0).
  Publishes `svc-wm decoration guard ok\n` (27 bytes).
- **`tests/README.md`** — fingerprint table + the two witness shapes
  this repo mixes (fingerprint-only vs. real-assertion) + the
  cross-process boundary rationale for #3/#5's deferred IPC branches.
- **`STATUS.md`** — per-milestone checklist (M1..M5), M1/M2 landed,
  M3..M5 open; naming-risk note on `KIND_INPUT_EVENT` vs. the design
  doc's `KIND_INPUT_FOCUS`.
- **`manifest.pdxsig`** — root-level source-form release manifest for
  v0.5.0 (scaffold-stage; dual-sign block placeholder pending the
  eventual M5 1.0.0 release per this org's convention).
- **`tools/build.sh`** — per-file `paideia-as build --emit elf64`
  assemble pass over `src/*.pdx` + `tests/*.pdx`, mirroring
  svc-compositor's own script byte-for-byte.

### Changed

- **`README.md`** — Scaffolding section updated: M1/M2 code has now
  landed (previously documented as "no code lands with this repo
  scaffold").

### Behaviour notes

- **Real bodies where the kernel substrate is live, honest witnesses
  where it isn't.** Unlike svc-compositor's own Wave Y drain (which
  stubbed every M1..M3 handler body because `sys_ipc_recv`/
  `sys_ipc_send`/`sys_svc_lookup` were not yet frozen at that repo's
  drain time), all three of those syscalls are live in the paideia-os
  kernel as of this wave — so `src/main.pdx`, `src/tiling.pdx`, and
  `src/decoration.pdx` all ship REAL bodies, not deferred stubs. What
  remains deferred is purely the CROSS-PROCESS integration check (no
  live `svc.compositor` process in this repo's own single-process
  smoke), documented per-witness in `tests/README.md`.
- **No division, no multiplication.** paideia-as exposes no
  `div`/`idiv` mnemonic; `tiling_divide` uses bounded repeated
  subtraction. 2-op `imul` is banned by this org's known encoder
  pitfalls and the column-width multiplicand is not a compile-time
  immediate in any case; `tiling_recompute` accumulates x-offsets via
  `add` instead of multiplying `index * column_width`.
- **Fixed 64-byte frame everywhere.** Every message this service sends
  or receives — its own 12 inbound shapes and both outbound ordinals to
  svc-compositor — is exactly 64 bytes (8-byte generic header + 56-byte
  payload), regardless of how many fields a given message actually
  uses. Unused payload bytes are explicitly zero-filled at every send
  site rather than relying on any implicit `uninit` zero-fill guarantee.

Closes paideia-os/svc-wm#1. Closes paideia-os/svc-wm#2.
Closes paideia-os/svc-wm#3. Closes paideia-os/svc-wm#4.
Closes paideia-os/svc-wm#5.

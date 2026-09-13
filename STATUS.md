# svc-wm — status

**Wave:** R102 (userland graphical stack, window manager)
**Current milestone:** M2 (tiling policy + focus outline) — **landed**,
closing Wave FF's five-issue cohort (#1..#5) in one v0.5.0 tag.
**Version:** 0.5.0.

See `design/graphics/r102-user-plan.md` §4.5 in the
[paideia-os](https://github.com/paideia-os/paideia-os) repo for the full
five-milestone breakdown this checklist mirrors.

## Milestone checklist

### M1 — Scaffold + caps.decl + frozen wire protocol + compositor registration

- [x] **M1-001** — repo scaffold. `README.md`, `LICENSE` (MIT),
      `CHANGELOG.md`, `caps.decl`, `tools/build.sh`, `manifest.pdxsig`
      (source form) all landed at v0.5.0. Closes #1.
- [x] **M1-002** — `caps.decl` (`KIND_USER` + `KIND_IPC_ENDPOINT` +
      `KIND_SURFACE` + `KIND_INPUT_EVENT`) + frozen wire protocol.
      `design/wire-protocol.md` documents all 12 message shapes
      (REGISTER_CLIENT .. GET_STATE), each a 64-byte fixed frame
      (8-byte generic header + 56-byte svc-wm payload). Probe witness
      at `tests/probe_wire_protocol.pdx` publishes
      `svc-wm wire-protocol frozen ok\n` (31 bytes). Closes #2.
- [x] **M1-003** — connect to `svc.compositor` + register. `src/main.pdx`
      (`Module Main`) is a REAL body: `sys_svc_lookup` (43) ->
      `sys_ipc_send` REGISTER_CLIENT (42) -> `sys_ipc_recv` REGISTER_OK
      (40), all three syscalls live in the kernel at this wave. Uses the
      same-endpoint reply assumption documented in the module header
      (design/wire-protocol.md §1) pending a live multi-process
      integration check. Probe witness at `tests/probe_register.pdx`
      stays fingerprint-only (no live `svc.compositor` in a single-repo
      smoke — see `tests/README.md`). Closes #3.

### M2 — Tiling policy + focus outline decoration

- [x] **M2-001** — fixed-column vertical tiling policy. `src/tiling.pdx`
      (`Module Tiling`): dense packed-array attach/detach (up to 8
      surfaces), `tiling_divide` (repeated-subtraction — paideia-as has
      no `div`/`idiv`), `tiling_recompute` (pure geometry pass, no
      multiplication — running-offset accumulation instead), and
      `tiling_emit_moves` (real `SURFACE_MOVE` emission over
      svc-compositor's frozen `WM_PLACE_WINDOW = 0x10`). Probe witness
      at `tests/probe_tiling.pdx` runs REAL assertions (attach/detach/
      recompute arithmetic) before publishing
      `svc-wm tiling policy ok\n` (24 bytes) — not a fingerprint-only
      stub. Closes #4.
- [x] **M2-002** — focus outline decoration. `src/decoration.pdx`
      (`Module Decoration`): `decoration_on_focus_change` un-decorates
      the previously-focused surface (border_width_px=0) then decorates
      the newly-focused one (RGB 0x00A0FF, 2px) over svc-compositor's
      frozen `WM_SET_FOCUS = 0x11`. Probe witness at
      `tests/probe_decoration.pdx` runs a REAL assertion (the no-IPC
      no-op guard path) before publishing
      `svc-wm decoration guard ok\n` (27 bytes). Closes #5.

### M3 — Real KIND_INPUT_FOCUS mint + Alt+Space command palette (not started)

- [ ] **M3-001** — real focus-capability mint, retiring the
      `KIND_INPUT_EVENT` placeholder this repo's `caps.decl` currently
      declares (see "Naming risk" below).
- [ ] Alt+Tab / Alt+F4 / Alt+Space dispatch loop against the 12 frozen
      message shapes (currently policy-only building blocks; no
      `sys_ipc_recv` server loop lands until M3).

### M4 — Smokes (tile arithmetic, focus cycle, palette dispatch) — not started

### M5 — Signed 1.0.0 release — not started

## What v0.5.0 does NOT ship

- No inbound message dispatch loop on `svc.wm`'s own registered
  endpoint. `src/main.pdx` only drives the OUTBOUND connect-to-
  compositor path; a `sys_ipc_recv` server loop answering the 12 frozen
  request shapes is M3+ scope.
- No live cross-process integration test. `tests/probe_register.pdx`
  and `tests/probe_decoration.pdx`'s IPC branch both require a running
  `svc.compositor` this repo's single-process smoke cannot provide;
  deferred to the monorepo's multi-process boot smoke.
- No real `KIND_INPUT_FOCUS`/`KIND_INPUT_EVENT` mint — `caps.decl`
  declares the kind as a forward-compat placeholder only.
- No live dual-signature on `manifest.pdxsig` — placeholder slots per
  this org's M5 convention.

## Naming risk

`caps.decl` declares `KIND_INPUT_EVENT` per this wave's dispatch
instructions, but `design/graphics/r102-user-plan.md` §7.2.2 names the
equivalent real capability `KIND_INPUT_FOCUS`. No numeric ordinal is
frozen for either name at v0.5.0 (no mint occurs before M3-001), so this
is a documentation-only discrepancy for now — flagged here so the M3-001
closer reconciles the name before minting anything real.

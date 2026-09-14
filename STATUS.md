# svc-wm — status

**Wave:** R102 (userland graphical stack, window manager)
**Current milestone:** M1..M5 all **landed**. Wave YY closes the
M3-002 + M4 (three smokes) + M5 five-issue cohort (#8, #9, #10, #11,
#12) in one v1.0.0-src tag.
**Version:** 1.0.0.

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
- [x] **M2-003** — Alt+Tab cycle + Alt+F4 close. `src/main.pdx`
      (`Main::main_dispatch`): decodes `ALT_TAB`(0x08)/`ALT_F4`(0x09)
      and drives `Tiling::tiling_focus_advance` (wraps the focus index
      modulo `swm_tile_count`, then updates the decoration outline and
      mints a fresh `KIND_INPUT_FOCUS`) and `Tiling::tiling_focus_close`
      (forward-declared `WM_CLOSE_WINDOW = 0x12` emission + local
      detach + re-tile). `WM_CLOSE_WINDOW` is NOT yet frozen in
      svc-compositor's own `caps.decl` -- documented risk, see
      `src/tiling.pdx`'s module header. Closes #6.

### M3 — Real KIND_INPUT_FOCUS mint + Alt+Space command palette

- [x] **M3-001** — real focus-capability mint. `src/focus.pdx`
      (`Focus::focus_mint`): real `sys_cap_mint` (sysno 5) call shape,
      `(kind, target_ptr, rights)` matching the kernel's actual
      `Mint.cap_mint`. Floor-only today -- sysno 5 is ENOSYS at HEAD per
      design/audit/entries/r13-m5-003-syscall-table.md's documented
      arity-mismatch gap -- but the call site is real, not a stub; it
      starts minting for real with zero source changes once the kernel
      lands its handler. Retires the `KIND_INPUT_EVENT` placeholder
      (see "Naming risk", now resolved below). Closes #7.
- [x] **M3-002** — Alt+Space command palette. `src/palette.pdx`
      (`Module Palette`): `palette_open` positions a centered 200x100
      overlay via svc-compositor's frozen `WM_PLACE_WINDOW = 0x10`, then
      best-effort blits the 3-command menu (swap-columns, close-focused,
      quit-wm) via a forward-declared `WM_BLIT = 0x13` (not yet frozen
      in svc-compositor's own `caps.decl`, same posture as
      `WM_CLOSE_WINDOW`). `palette_dispatch(cmd_id)` routes to
      `Tiling::tiling_focus_close` (close-focused), an in-place
      `swm_tile_ids` swap + `Tiling::tiling_emit_moves` (swap-columns),
      or a placeholder quit-intent flag (quit-wm), closing the palette
      on every known command. `Main::main_dispatch` now also routes
      `ALT_SPACE_PALETTE` (0x0A) to `palette_open`. Closes #8.
- [ ] A real `sys_ipc_recv` server loop feeding `main_dispatch` from
      svc-wm's own `svc.wm` endpoint remains open (M2-003/#6 landed the
      decoded-request handling half only; see `src/main.pdx`'s module
      header "Wave VV addendum").

### M4 — Smokes (tile arithmetic, focus cycle, palette dispatch) — landed

- [x] **M4-001** — tile arithmetic smoke. `tests/svc_wm_tile_smoke.pdx`
      asserts `tiling_divide(1920,3)==640`, `tiling_divide(1920,4)==480`,
      and `tiling_divide(100,3)==33` (with the 1px remainder pinned via
      subtraction, not redistributed -- `tiling_recompute` does not do
      that). Publishes `svc-wm tile-math ok\n` (20 bytes). Closes #9.
- [x] **M4-002** — focus cycle smoke. `tests/svc_wm_focus_cycle_smoke.pdx`
      attaches 3 fake surfaces and asserts `tiling_focus_advance`'s
      4-call index sequence is 1,2,0,1. Publishes
      `svc-wm focus-cycle ok\n` (22 bytes). Closes #10.
- [x] **M4-003** — palette dispatch smoke.
      `tests/svc_wm_palette_smoke.pdx` asserts `palette_dispatch(1)`
      (close-focused) records the mock-dispatch signal
      (`swm_palette_last_action==1`), closes the palette
      (`swm_palette_open==0`), and returns `Tiling::SWM_TILE_ERR_LOOKUP`
      deterministically (no live `svc.compositor` in this single-process
      smoke -- same boundary as `probe_register.pdx`). Publishes
      `svc-wm palette-dispatch ok\n` (27 bytes). Closes #11.

### M5 — Signed 1.0.0 release — landed

- [x] **M5-001** — `CHANGELOG.md`/`README.md`/`manifest.pdxsig` bumped
      to 1.0.0; `v1.0.0-src` tag. Dual-signature block stays
      PLACEHOLDER (unsigned) pending the release-time key-material pass
      -- see `manifest.pdxsig`'s own header for that convention. Closes
      #12.

## What v1.0.0-src does NOT ship

- No inbound `sys_ipc_recv` server loop on `svc.wm`'s own registered
  endpoint feeding `main_dispatch`. `src/main.pdx` still only drives the
  OUTBOUND connect-to-compositor path for real IPC; `main_dispatch`
  itself is real and callable, but nothing yet decodes an inbound wire
  frame and calls it. See `src/main.pdx`'s module header "Wave VV
  addendum".
- `WM_CLOSE_WINDOW = 0x12` and `WM_BLIT = 0x13` (svc-wm's own forward-
  declared ordinals) are NOT yet frozen in svc-compositor's `caps.decl`
  -- svc-wm sends the real frames regardless; see `src/tiling.pdx`'s and
  `src/palette.pdx`'s module headers.
- `sys_cap_mint` (sysno 5) is ENOSYS at HEAD (documented kernel arity
  mismatch, design/audit/entries/r13-m5-003-syscall-table.md) --
  `focus_mint`'s call site is real, but every mint attempt returns
  `-ENOSYS` until the kernel lands its handler.
- The command palette overlay is not a real compositor-minted
  `KIND_SURFACE` (no `SURFACE_CREATE` wire op is frozen on
  `svc.compositor.wm`) -- `SWM_PALETTE_SURFACE_ID` is a WM-owned
  pseudo-id; see `src/palette.pdx`'s module header.
- `Palette::palette_dispatch`'s quit-wm branch only records a
  `swm_palette_quit_requested` intent flag -- no real recv loop consumes
  it yet (same gap as the bullet above).
- No live cross-process integration test. `tests/probe_register.pdx`,
  `tests/probe_decoration.pdx`'s IPC branch, and
  `tests/svc_wm_palette_smoke.pdx`'s close-focused branch all require a
  running `svc.compositor` this repo's single-process smoke cannot
  provide; deferred to the monorepo's multi-process boot smoke.
- No live dual-signature on `manifest.pdxsig` — placeholder slots per
  this org's M5 convention.

## Naming risk (resolved)

`caps.decl` declared `KIND_INPUT_EVENT` as a v0.5.0 working name;
`design/graphics/r102-user-plan.md` §7.2.2 names the real capability
`KIND_INPUT_FOCUS`. Resolved at v0.6.0 (#7): `caps.decl` now declares
`KIND_INPUT_FOCUS` directly, minted by `src/focus.pdx`'s `focus_mint`.
The NUMERIC ordinal (`0x1BA`, `Focus::SWM_FOCUS_KIND_INPUT_FOCUS`)
remains a locally-declared placeholder pending the authoritative R101
kernel-side freeze -- see that module's header.

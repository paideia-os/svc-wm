# svc-wm — status

**Wave:** R102 (userland graphical stack, window manager)
**Current milestone:** M2 (tiling policy + focus outline) — **landed**
in full; M3 — **M3-001 landed**, M3-002 (Alt+Space palette) open.
Wave VV closes the M2-003 + M3-001 two-issue cohort (#6, #7) in one
v0.6.0 tag.
**Version:** 0.6.0.

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
- [ ] Alt+Space command palette (M3-002, not started).
- [ ] A real `sys_ipc_recv` server loop feeding `main_dispatch` from
      svc-wm's own `svc.wm` endpoint remains open (M2-003/#6 landed the
      decoded-request handling half only; see `src/main.pdx`'s module
      header "Wave VV addendum").

### M4 — Smokes (tile arithmetic, focus cycle, palette dispatch) — not started

### M5 — Signed 1.0.0 release — not started

## What v0.6.0 does NOT ship

- No inbound `sys_ipc_recv` server loop on `svc.wm`'s own registered
  endpoint feeding `main_dispatch`. `src/main.pdx` still only drives the
  OUTBOUND connect-to-compositor path for real IPC; `main_dispatch`
  itself is real and callable, but nothing yet decodes an inbound wire
  frame and calls it. See `src/main.pdx`'s module header "Wave VV
  addendum".
- `WM_CLOSE_WINDOW = 0x12` (svc-wm's own Alt+F4 close ordinal) is NOT
  yet frozen in svc-compositor's `caps.decl` -- svc-wm sends the real
  frame regardless; see `src/tiling.pdx`'s module header.
- `sys_cap_mint` (sysno 5) is ENOSYS at HEAD (documented kernel arity
  mismatch, design/audit/entries/r13-m5-003-syscall-table.md) --
  `focus_mint`'s call site is real, but every mint attempt returns
  `-ENOSYS` until the kernel lands its handler.
- No live cross-process integration test. `tests/probe_register.pdx`
  and `tests/probe_decoration.pdx`'s IPC branch both require a running
  `svc.compositor` this repo's single-process smoke cannot provide;
  deferred to the monorepo's multi-process boot smoke.
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

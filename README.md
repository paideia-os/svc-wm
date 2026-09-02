# svc-wm

The window manager service — a **separate** process from svc-compositor per Pillar 6 (compositor lockup does not kill WM policy). Owns tiling policy (fixed-column vertical at v1), 1-pixel focus outline decoration, click-to-focus + Alt+Tab focus cycling, Alt+F4 close, Alt+Space command palette. Mints `KIND_INPUT_FOCUS` for the focused window.

Part of the **paideia-os** organization. MIT-licensed.

## Wave

R102 (softarch userland graphical stack) — the CPU-side framebuffer stack
that lands the first graphical UI on paideia-os before the G-series
GPU-accelerated compositor matures. Companion to the osarch R101 kernel-side
plan.

## Design reference

- Design lives in the monorepo at [`design/graphics/r102-user-plan.md`](https://github.com/paideia-os/paideia-os/blob/main/design/graphics/r102-user-plan.md) §2.5 / §4.5.
- Kernel-side companion: `design/graphics/r101-kernel-plan.md`.

## Milestones

Per the plan, this repo lands across five milestones:

- **M1** — repo scaffold; caps.decl (KIND_INPUT_FOCUS stub + IPC endpoint to compositor); frozen wire protocol; connect + register on svc.compositor
- **M2** — tiling policy (fixed-column vertical); focus outline; Alt+Tab cycle; Alt+F4 close
- **M3** — real KIND_INPUT_FOCUS mint; Alt+Space command palette (3-command menu)
- **M4** — smokes: tile arithmetic, focus cycle, palette dispatch
- **M5** — signed 1.0.0 release

Every issue is filed against one of these five milestones; see the Issues tab.

## Scaffolding

No code lands with this repo scaffold — scaffolding lives in the M1
issues (`caps.decl`, `src/` skeleton, public API stubs, argv parsing).
Repo shape mirrors R100 satellites: paideia-as manifest at root,
`caps.decl` at root, `src/` module tree, `tests/`, `release/`,
`doc/<name>.pdxdoc`, dual-signed `manifest.pdxsig` at 1.0.0.

## License

MIT. See [LICENSE](LICENSE).

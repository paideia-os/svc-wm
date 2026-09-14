# svc-wm tests

Boot-time smoke witnesses for the R102 window manager. Each file in this
directory is a **standalone** `.pdx` driver -- `tools/build.sh` compiles
every `tests/*.pdx` into a `.o` alongside `src/*.pdx`, but the smokes are
never linked into the service ELF (they are the payload for
`paideia-os/tools/run-smoke.sh` to grep after a QEMU boot).

## Two witness shapes in this repo

Unlike a pure fingerprint-only witness, three of the five drivers below
run REAL assertions against the linked `src/*.pdx` policy functions
before publishing their fingerprint -- the "assertion added before the
`sys_write`" shape this org's honest-witness convention documents as the
eventual target for every deferred witness (see svc-compositor's own
`tests/README.md`). The other two remain fingerprint-only because their
milestone's real behaviour needs a live cross-process `svc.compositor`
this single-repo smoke cannot provide.

| Driver                      | Kind             | Real assertions | Issue |
|------------------------------|-----------------|------------------|-------|
| `probe_scaffold.pdx`         | fingerprint-only | none (scaffold has no runtime behaviour) | #1 |
| `probe_wire_protocol.pdx`    | fingerprint-only | none (protocol freeze is data/docs only) | #2 |
| `probe_register.pdx`         | fingerprint-only | deferred -- needs a live `svc.compositor` | #3 |
| `probe_tiling.pdx`           | **real**          | attach/detach/recompute/divide arithmetic | #4 |
| `probe_decoration.pdx`       | **real**          | no-IPC no-op guard path | #5 |
| `svc_wm_tile_smoke.pdx`      | **real**          | `tiling_divide` arithmetic (3/4-column + remainder) | #9 |
| `svc_wm_focus_cycle_smoke.pdx` | **real**        | `tiling_focus_advance` modulo-3 wraparound sequence | #10 |
| `svc_wm_palette_smoke.pdx`   | **real**          | `palette_dispatch` close-focused routing (deterministic lookup-fail path) | #11 |

## Fingerprint table

| Driver                        | Fingerprint                          | Bytes | Issue |
| ------------------------------ | ------------------------------------- | ----- | ----- |
| `probe_scaffold.pdx`           | `svc-wm scaffold ok\n`                | 19    | #1    |
| `probe_wire_protocol.pdx`      | `svc-wm wire-protocol frozen ok\n`    | 31    | #2    |
| `probe_register.pdx`           | `svc-wm register-client wired ok\n`   | 32    | #3    |
| `probe_tiling.pdx`             | `svc-wm tiling policy ok\n`           | 24    | #4    |
| `probe_decoration.pdx`         | `svc-wm decoration guard ok\n`        | 27    | #5    |
| `svc_wm_tile_smoke.pdx`        | `svc-wm tile-math ok\n`               | 20    | #9    |
| `svc_wm_focus_cycle_smoke.pdx` | `svc-wm focus-cycle ok\n`             | 22    | #10   |
| `svc_wm_palette_smoke.pdx`     | `svc-wm palette-dispatch ok\n`        | 27    | #11   |

## Why `probe_register.pdx` stays fingerprint-only despite `src/main.pdx`
being a real body

`Main::run` (src/main.pdx) issues real, live syscalls
(`sys_svc_lookup`/`sys_ipc_send`/`sys_ipc_recv`, all landed in the
paideia-os kernel at Wave FF drain) -- it is not a deferred stub. But
exercising it end to end requires `svc.compositor` already registered
on `svc_broker` in a second process, which this repo's single-process
smoke cannot orchestrate. Calling it here would either deadlock in
`sys_ipc_recv` or return a deterministic `-ENOENT`, neither of which is
the "round trip succeeded" claim a witness must not fabricate. The
retargeting note in `probe_register.pdx`'s own header names the upgrade
path once the monorepo's multi-process boot smoke exists.

## Return-code convention (org-wide)

Matches this org's established M4-driver convention:

- `0` -- witness ran and every assertion (if any) held.
- `1..N` -- a per-driver failure; `probe_tiling.pdx` encodes which
  specific assertion failed (1..13, see its own module header); every
  other driver returns `1` for its single failure mode (`sys_write`
  returned negative, or the guarded assertion did not hold).

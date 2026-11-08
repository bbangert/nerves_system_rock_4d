# rock-4d-target — scratchpad (decisions, dead-ends, measurements)

## Decisions carried from the brainstorm (2026-11-08)
See `interview.md` items 1–11. Correction applied: U-Boot `ENV_IS_IN_SCSI` selects the env
partition by the partition's UNIQUE GUID (`CONFIG_ENV_SCSI_PART_UUID`), not type GUID/name.

## Plan-time decisions (2026-11-08)
- U-Boot is built INSIDE Buildroot (`BR2_TARGET_UBOOT`) rather than via isaiahdw's Docker
  `scripts/build-uboot.sh`: the devcontainer has no docker and no swig; Buildroot supplies
  host-swig/pylibfdt; one reproducible artifact per system build. His script is kept only as
  documentation unless it conflicts.
- The fork's `fwup.conf` targets UFS and REPLACES the SD layout (single U-Boot env location,
  single layout). Re-adding SD as a build variant is upstream-time work (out of scope, Ben).
- Env partition p1 type GUID: generic Linux data unless U-Boot/fwup need otherwise.
- librknnrt: default keep 2.3.2; bump to 2.5.0 only if the `.mk` URL pattern holds (0.4).

## Open hardware facts (fill at Phase 2)
- Board silkscreen rev: ?
- SPI NOR chip (dmesg / sf probe): ?
- UFS module model/capacity: ?  `blockdev --getss --getpbsz` via reader: ?
- `scsi info` → user LUN index: ?
- RAM: ?
- Boot time to IEx (timestamped): ?

## Dead-ends
- (none yet)

## Phase 0 findings (2026-11-08)
- 0.0: fork `bbangert/nerves_system_rock_4d` exists (fork of isaiahdw, main == upstream/main
  68a59dd = v0.1.1). Clone at /workspaces/nerves_system_rock_4d, remotes origin/upstream,
  branch `ufs-boot`. **His repo has NO `.github/` at all** — releases were manual uploads
  (asset `nerves_system_rock_4d-portable-0.1.1-9F869E3.tar.gz`, 258 MB, contentType
  x-gtar; the `-portable-<ver>-<CHECKSUM7>.tar.gz` name is what `mix nerves.system.release`
  / `nerves.artifact` produces). → Phase 2.8 MUST add `.github/workflows/release.yml`
  (model: nerves_system_dragon_q6a's ci.yml). `artifact_sites` in mix.exs points at
  `isaiahdw/...` → switch `@github_organization` to `bbangert` in 0.1 so Phase 3 fetches
  from the fork's releases.
- Resolved pins: rkr7.2 HEAD = 858550966271b1f59897a106bc3f92842ea0e750 (still branch tip
  2026-11-08); radxa-pkg/aic8800 release `5.0+git20260123.5f7be68d-10` (2026-10-12) =
  e9e43ed79c50483080e9bcdfb08caeeb869d7191; JeffyCN/mirrors `libmali-next` HEAD =
  bf621d15f009509557d6b28f81427651695cac20 (2026-09-21); toolchain 15.3.1 URL tag
  `15.3.1-C0D130A` (copy from dragon_q6a nerves_defconfig:5) + `BR2_TOOLCHAIN_EXTERNAL_GCC_15=y`.
- 0.4 librknnrt DECISION: keep 2.3.2. The v2.5.0 URL pattern DOES hold (same
  `rknpu2/runtime/Linux/librknn_api/aarch64/librknnrt.so`, 8,189,368 B, same 3 headers) so a
  later bump is one line, but 2.5.0's minimum rknpu driver is unextractable and rknpu stays
  0.9.8 in rkr7.2 — 2.3.2 ↔ 0.9.8 is the hardware-proven pair (his v0.1.0). Revisit after
  the Phase 2 NPU gate.
- Devcontainer: erlang 29.1.2 + elixir 1.20.2-otp-29 installed via mise; nerves_bootstrap
  1.17.3; ~/.nerves/dl has 15 GB of Buildroot downloads (cache). No swig/gdisk/pytest/
  rkdeveloptool on the host. 32 cores, 187 GB RAM, 289 GB free.
- 0.6 BUILD GREEN (2026-11-08): `mix compile` in the fork, 04:39:06 → 05:01:38 (22 min, warm
  ~/.nerves/dl cache + 32 cores), EXIT=0. Artifact dir
  `.nerves/artifacts/nerves_system_rock_4d-portable-0.2.0-dev/`. Evidence: kernel.release
  `6.1.172`; `.config` has SCSI_UFSHCD=y, SCSI_UFS_ROCKCHIP=y, MALI_BIFROST=y,
  MALI_PLATFORM_NAME="rk", MALI_BIFROST_DEBUG unset, ROCKCHIP_RKNPU=y, REALTEK_PHY=y, F2FS=y,
  WL_ROCKCHIP/CFG80211=m; `target/usr/lib/libmali-bifrost-g52-g29p1-gles.so` (23.5 MB)
  strings `arm_release_ver: g29p1-12eac0`; modules `6.1.172/extra/{aic_load_fw,aic8800_fdrv,
  aic_btusb}.ko` + firmware under `aic8800_fw/USB/aic8800D80`; librknnrt 2.3.2 on target;
  images: Image 40.7 MB, rk3576-rock-4d-spi.dtb, rootfs.squashfs 32.6 MB, uboot-env.bin,
  the committed u-boot-rockchip-spi.bin (still the v2026.01 blob — Phase 1 replaces it).
  Log: scratchpad/build-0.6.log (session 05a71ad8).
- 0.7 pre-push review (code-review skill, medium): 5 findings. FIXED: README SD row read as
  already replaced + dep snippet tag v0.2.0 not yet existing + CHANGELOG past tense +
  aic8800.mk comment attributing the full fw path to patch 0006 (0006 sets the
  `aic8800_fw/USB` prefix; the driver appends `aic8800D80` itself). INVALID: "Mali fragment
  pins only 3 symbols, rest fall to defaults" — the rkr5.1 rockchip_linux_defconfig itself
  set exactly MALI_BIFROST / PLATFORM_NAME="rk" / BIFROST_EXPERT / BIFROST_DEBUG and nothing
  else for Bifrost (defconfig = non-defaults only), so DEVFREQ/GATOR/PRFCNT etc. were Kconfig
  defaults under the vendor config too; the fragment reproduces the vendor's explicit set
  (DEBUG off, as his v0.1.x already did). Built .config has BIFROST_DEVFREQ=y, GATOR=y,
  PRFCNT_SET_PRIMARY=y, REAL_HW=y.
- 0.7: PR #1 opened on the FORK (bbangert/nerves_system_rock_4d, base main, head ufs-boot @aae7916)
  2026-11-08 — https://github.com/bbangert/nerves_system_rock_4d/pull/1 . `gh repo set-default`
  pinned to the fork in that clone so no gh command targets isaiahdw's repo. Copilot round 1
  requested.
- 0.7 Copilot round 1 (head aae7916): 1 finding (High) — SDIO `get_fw_path` override branch
  copies `aic_fw_path` without NUL; new 0027 callers pass uninit `fw_dir`. VALID in the code,
  OUT OF SCOPE here: `src/SDIO/` is never built (USB-only MODULE_SUBDIRS) and the series is a
  verbatim radxa-pkg mirror. Declined on-thread + resolved; no push → no re-request. Loop
  closed at 0 open. UNFILED upstream: radxa-pkg/aic8800 0027 `get_fw_path` NUL bug (SDIO).
- PHASE 0 COMPLETE 2026-11-08 — PR #1 awaits Ben's merge. STOP at phase boundary.
  Phase 1 start = `/phx:work bringup/plan/plan.md` in a fresh session after
  the merge; branch from the merged fork main.
- CORRECTION (Ben, 2026-11-08): PR #1 was merged after I self-declined Copilot's High finding;
  convergence = Copilot's OWN review approves / 0 open + 0 missed. Follow-up PR #2
  (fix/aic8800-sdio-nul): fork-local patch 0030 NUL-terminates the SDIO get_fw_path override;
  Buildroot aic8800 rebuild applied 30/30. Copilot round 1 requested on #2. Phase 1 branch NOT
  created yet (earlier attempt was rejected) — create `ufs-boot-chain` from main after #2 merges.
- PR #2 Copilot round 1 @e328535: "Approval recommended", 0 open, no missed notes → CONVERGED.
  MERGED 2026-11-08. The PR #1 High finding is closed by #2.
## Phase 1 (started 2026-11-08, branch `ufs-boot-chain` from fork main 91e8deb)
- DECISION rkbin: Buildroot 2026.08.1 `package/rockchip-rkbin` is pinned to f43a462e
  (2025-01-24) → only DDR v1.09 / BL31 v1.15 for rk3576; the research's v1.13/v1.25 (rkbin
  3e288fe) are absent. A fork-local rkbin package can't become a U-Boot dependency from
  BR2_EXTERNAL (external .mk is included after uboot's eval). → commit isaiahdw's
  HARDWARE-PROVEN pair (DDR v1.12 + BL31 v1.24 at his RKBIN_COMMIT, scripts/build-uboot.sh)
  under uboot/rkbin/ with LICENSE + provenance, pass via BR2_TARGET_UBOOT_CUSTOM_MAKEOPTS.
  Deviation from the plan's v1.13/v1.25: proven-on-this-board beats newer.
- U-Boot: v2026.10 is now a stable tag; agent uses it iff it has UFS_ROCKCHIP+SPL_UFS+XMC,
  ENV_SCSI_PART_UUID, FAT sector-mismatch option and UFS device reset; else v2027.01-rc1.
- Host has no sfdisk/gdisk/pytest/pip → image-tool tests use stdlib unittest; GPT checks by
  parsing in Python (and partx if usable).
- 1.6/1.7 DONE (agent): tools/mk_ufs_image.py + 17 unittest tests (independent GPT reader,
  break-test proved GUID-preservation test bites) + scripts/flash-ufs.sh (bash -n/shellcheck
  clean). Output .img ≈1.77 GiB sparse (through data min). FOUND Q6A BUG (UNFILED, out of
  scope): nerves_system_dragon_q6a tools/mk_ufs_image.py zeroes the stale 512-LBA backup GPT
  starting at backup_lba*512 forward, but fwup's backup entries sit 32 sectors BEFORE the
  backup header → wrong bytes zeroed, stale entries left. Rock 4D tool zeroes from the
  source backup header's entries_lba through its header sector.
- 1.1–1.5 DONE (agent): U-Boot v2027.01-rc1 in Buildroot (v2026.10 lacks CONFIG_SPI_FLASH_XMC in
  rock-4d defconfig — commit 64d6610cf4, 2026-08-12, V1.12-board XMC fix); env UUID
  a8319de8-8a9f-4eba-968c-fde1f93ec6b5 (fragment == fwup p1 guid, check-env-uuid.sh in
  post-build, break-tested: make exit 2); `# CONFIG_ENV_REDUNDANT is not set` (rc1 renamed
  SYS_REDUNDAND_ENVIRONMENT); rkbin ecb4fcbe DDR v1.12 + BL31 v1.24 committed. binman map:
  u-boot-rockchip-spi.bin 1,632,256 B, FIT @0x60000 size 0x12E800, ends 0x18E800 → ~14.4 MiB
  NOR free. Arch stays `aarch64` (his + Q6A value; plan said arm64 — wrong). Upgrades now
  unset `<slot>.nerves_fw_validated` (complete sets a.*=1; stale 1 would mask an unvalidated
  later upgrade back to A). README maskrom keeps his `rkdeveloptool cs 9` (select SPI NOR).
- 1.8 image gate: devcontainer has NO loop devices (/dev/loop*, loop-control, modprobe absent)
  → `losetup -b 4096` impossible here; kernel-parse proof moves to the board. Independent
  Python GPT parse of mk_ufs_image(test.img, 16G --full): primary @LBA1, entries LBA2,
  first/last usable 6/4194298, backup hdr @4194303 (alt=1), all CRCs ok, disk GUID + all 5
  unique/type GUIDs + byte starts preserved, data grown to 16 GiB−24 KiB, env CRC ok,
  boot_targets=scsi present, bootfs BPB 512, rootfs-a `hsqs`. Clean rebuild running
  (log scratchpad/build-1.8-clean.log).
- 1.8 CLEAN BUILD GREEN 06:22:55→06:48:22 (25 min), EXIT=0; u-boot-rockchip-spi.bin sha256
  74ded6ec…bb8d9 identical to the incremental build (reproducible); target has no /boot,/mnt/boot.
- 1.9 local code-review (high), 10 findings. FIXING: fw_env via p1 vs fwup via whole disk
  (separate page caches; fwup O_DIRECT) → `/dev/rootdisk0 0x100000 0x20000`; `scsi 0:2`
  hardcode → nerves_find_disk loops scsi 0..7 matching `part uuid :1` to nerves_env_uuid;
  define! on env GUID/geometry; check script → check-env-config.sh (UUID ×3, size ×4, offset);
  flash-ufs mount guard via /proc/self/mounts; 128G example; DELETE legacy blob +
  build-uboot.sh (deviation from plan 1.1 "delete after 1.8 proves": it can't read the UFS env
  at all, same filename as the built image — no fallback value). DECLINED: `complete` guard
  (also used by `mix firmware.image`, which produces the image file the tool consumes; fwup
  can't tell file vs device), factory-reset trims only 512 MiB (header invalidation → reformat;
  same as every Nerves system with expand), ~1 GB zeros per flash (seconds, keeps module clean).
- PR #3 opened (https://github.com/bbangert/nerves_system_rock_4d/pull/3). Copilot r1 (@d99bc1c):
  4 valid (dm/LVM holder ancestry in flash guard, --out aliasing --input truncates source,
  README sudo, test read 1.8 GiB into RAM) → fixed b159b57, replied+resolved, re-requested.
  r2 (@b159b57): 1 thread + 2 MISSED notes, all valid: re-check in-use before dd; outputs
  aliasing each other; **bootfs not marked bootable → `bootflow scan` scans ONLY p1 when no
  partition is bootable (U-Boot bootdev-uclass.c:170-175), and p1 is now the raw env → the
  corrupt-env extlinux recovery path was dead.** Fix: GPT legacy-bootable attr (bit 2) on
  bootfs + mk_ufs_image must preserve attributes. Real catch for bring-up.
- PR #3 r3 (@e589757): 0 open + 1 missed (uppercase nerves_env_uuid passed the case-folded
  check but U-Boot `test` is exact) → b29dfc6. r4 (@b29dfc6): "No open issues", 0 threads,
  0 missed → CONVERGED (headline mentioned USB-backed root; covered by holders + mounted-
  descendant checks, both re-run before dd). MERGED 2026-11-08. PHASE 1 COMPLETE.
## Phase 2 prep (2026-11-08) — WAITING ON BEN (hands-on)
- Bring-up app /workspaces/rock4d-bringup (nerves 1.15.1, nerves_pack 0.7.2; eth0 DHCP, ssh with
  devcontainer id_ed25519/id_rsa, mDNS rock4d.local, StartupGuard OFF so A/B tests keep an
  unvalidated slot). Build needs `NERVES_SYSTEM=/workspaces/nerves_system_rock_4d/.nerves/
  artifacts/nerves_system_rock_4d-portable-0.2.0-dev` + MIX_TARGET=rock_4d (path dep alone
  stops with "Nerves packages need to be built"; failed artifact download still exits 0).
- out/: rock4d_bringup.fw dea5e017…6382, u-boot-rockchip-spi.bin 74ded6ec…bb8d9,
  rk3576_spl_loader_v1.09.108.bin 3706ce51…07ac. Runbook handed to Ben.

# Radxa ROCK 4D (RK3576) — new Vagus target `rock_4d`, UFS-only, from a fork of isaiahdw/nerves_system_rock_4d

**Decision basis:** `interview.md` (Status: COMPLETE, 11 decisions) + `research/*.md`
(8 files, 3 cycles, all cited). Do NOT re-research. `research/comparison.md` is the
options-vs-baseline table; `research/uboot-dry-build.md` holds the proven U-Boot fragment;
`research/fwup-4kn-layout.md` holds the partition table; `research/kernel-rkr72.md` the
kernel pin proof; `research/codebase-scan.md` the nerves_system_vagus / vagus wiring map.

**DECIDED (Ben, 2026-11-08):** fork of isaiahdw/nerves_system_rock_4d (upstream-shaped, **no
upstream PRs in this work**) • Radxa **UFS module only** (4Kn), flashed in a USB reader •
Rockchip **vendor 6.1 `rk-6.1-rkr7.2`** (NPU + GPU are hard requirements) • **mainline U-Boot
v2027.01-rc1** in SPI NOR • Nerves env in a **GPT partition p1 on the UFS LUN**
(`ENV_IS_IN_SCSI`, selected by p1's UNIQUE GUID) • **one plan** fork → system release →
nerves_system_vagus subtree → vagus wiring → released `vagus_rock_4d.fw` • **one board**.

**Key facts the tasks rely on (verified 2026-11-08):**
- Baseline `isaiahdw/nerves_system_rock_4d@main` v0.1.1: rkr5.1 tarball `5280f9b4`, U-Boot
  v2026.01 blob (no UFS boot, no XMC NOR), SD boot, env on SD @0xF00000, extlinux A/B with
  `nerves_init`/`nerves_boot`/`nerves_revert` scripts, rknpu 0.9.8 + librknnrt 2.3.2, kbase
  g25p0 + libmali g24p0 blob, radxa-pkg/aic8800 @6e076049 (25 copied patches), br 1.34.0.
- rkr7.2 (6.1.172, HEAD 8585509, 2026-11-04): his `linux/0001-dts-rk3576-rock-4d-nerves-
  fixups.patch` applies with ZERO fuzz (both halves still needed); `rk3576-rock-4d-spi` dts
  and `rockchip_linux` defconfig exist; `&ufs` on with `reset-gpios`; rknpu 0.9.8 `=y`;
  kbase **g29p1-12eac0**; `MALI_BIFROST` DROPPED from the defconfig → his `linux/rk3576.config`
  is the only enabler. Blob: JeffyCN/mirrors branch `libmali-next`
  `libmali-bifrost-g52-g29p1-gles.so` embeds `g29p1-12eac0` (GBM/EGL symbols; Arm EULA).
- U-Boot v2027.01-rc1 (`dfcfc4c9`) `rock-4d-rk3576_defconfig` already has UFS/SCSI/SPL_UFS;
  our fragment survives `olddefconfig` and the tree compiles with the Nerves 15.3 toolchain
  (TPL/SPL/U-Boot proper built); binman packing needs **swig** (absent in this devcontainer).
  Fragment: `CONFIG_ENV_IS_IN_SCSI=y`, `CONFIG_ENV_SCSI_PART_UUID="<p1 unique GUID>"`,
  `CONFIG_ENV_SIZE=0x20000`, `# CONFIG_SYS_REDUNDAND_ENVIRONMENT is not set`,
  `CONFIG_FS_FAT_HANDLE_SECTOR_SIZE_MISMATCH=y`, `CONFIG_SPI_FLASH_XMC=y`,
  `CONFIG_SPI_FLASH_MACRONIX=y`, `CONFIG_SPI_FLASH_GIGADEVICE=y`, `CONFIG_SPI_FLASH_WINBOND=y`.
  rkbin@3e288fe: `bin/rk35/rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin`,
  `bin/rk35/rk3576_bl31_v1.25.elf`. SPL order `same-as-spl, sdmmc, sdhci, ufshc`; nothing
  scans SCSI at init (env load scans first) → add explicit `scsi scan` in `nerves_boot`.
  BootROM: FSPI0 → UFS → USB (SD never). ≈14.4 MiB NOR free after the FIT (computed).
- fwup v1.17.1 is 512-byte throughout: `.fw` + on-device A/B tasks work on 4Kn; `gpt_write`
  hardcodes 512 geometry → regenerate the GPT for 4096 (adapt Q6A `tools/mk_ufs_image.py`:
  it hardcodes names `config/efi/rootfs-a/rootfs-b/data`, exactly 5 partitions, data last,
  rejects starts < byte 24576); FatFs fixed at 512 → bootfs is a 512-BPB FAT (U-Boot reads
  it via the mismatch option; Linux must NOT mount it). **Never `fwup -d /dev/sdX` on the
  module.** erlinit derives `/dev/rootdisk0pN` from `/`; Vagus Provisioner hardcodes `p5`
  and skips `expand-data` unless logical block size is 512.
- Layout (4096 LBAs, MiB-aligned; fwup 512-offsets in `research/fwup-4kn-layout.md:57-64`):
  p1 env 1 MiB @1 MiB (fwup `UBOOT_ENV_OFFSET=2048`, count 256 = 128 KiB) • p2 bootfs FAT
  256 MiB @16 MiB (512-off 32768) • p3 rootfs-a 512 MiB @272 • p4 rootfs-b 512 MiB @784 •
  p5 data @1296 MiB, sized at image build to the module. `complete` sets
  `a.nerves_fw_validated=1` (else StartupGuard reboot-cycles every 15 min).
- nerves_system_vagus layering: product repo vendors the base via `git subtree --squash`
  under `<target>/base/`, `scripts/sync-base.sh` generates `nerves_defconfig`, `Config.in`,
  `rootfs_overlay/etc/erlinit.config` from `base/` + `*.fragment`; `Makefile` lines 25/28/30
  (`BASE_TARGETS`, `BASE_REPO_<target>`), `.github/workflows/build.yml` matrix line 57;
  `check-base-pristine` diffs `base/` against the base repo's tagged `VERSION`; sync-base
  fails unless the target `mix.exs` pins `nerves_system_br` + toolchain to `base/mix.exs`.
- vagus wiring: `@all_targets` in `apps/vagus/mix.exs` and `apps/vagus_platform/mix.exs`,
  path dep block `apps/vagus_platform/mix.exs:59-73`, **required** `config/rock_4d.exs`
  (`config/target.exs:416-421` hard-fails without it), `release.yml` matrix +
  `SYSTEM_RELEASE_TAG`, `NERVES_FW_PLATFORM=rock_4d` (OS updater derives
  `vagus_<platform>.fw`), `.mise.toml`; Host RAM profile is runtime (≥2 GiB → fast; spool fix
  shipped in 0.13.1); BlueZ + `main.conf` LE interval live in the product layer.
- Hardware-blocked unknowns: NOR chip revision (silkscreen / `dmesg | grep spi-nor` /
  `/sys/bus/spi/devices/spi5.0/spi-nor/partname`), which UFS LUN is `scsi 0` (`scsi info`),
  the reader's presented sector size (`blockdev --getss --getpbsz`), module capacity.

**Execution notes:** all coding delegated to subagents (haiku/sonnet/opus by difficulty — NO
code edits in the main loop); **PR per phase, STOP at each phase boundary**; local reviews +
the repo code-review skill before the first push; Copilot loop on every PR; builds run
natively in the devcontainer (no docker) — U-Boot is built INSIDE Buildroot so host-swig
comes from Buildroot. Log decisions/dead-ends in `scratchpad.md`. Repos: fork clone at
`/workspaces/nerves_system_rock_4d` (user creates the GitHub fork), `/workspaces/
nerves_system_vagus`, `/workspaces/vagus`. Classifier-blocked for the agent: fork/public repo
creation, tag pushes, force pushes → user.

---

## Phase 0 — Fork + pins (no board) `[system]`

- [x] 0.0 **User:** `gh repo fork isaiahdw/nerves_system_rock_4d --clone=false`; agent clones
      `bbangert/nerves_system_rock_4d` to `/workspaces/nerves_system_rock_4d`, adds `upstream`
      remote, branch `ufs-boot`. Read `.github/workflows/*` to learn how his CI builds +
      releases (artifact name, `mix nerves.system.release`?) — record in scratchpad. — DONE: clone +
      remotes + `ufs-boot` branch; his repo has NO `.github/` (manual releases, asset
      `-portable-0.1.1-9F869E3.tar.gz`) → 2.8 adds release.yml; `artifact_sites` → bbangert in 0.1.
- [x] 0.1 Pin bump: `mix.exs` `nerves_system_br` 1.34.0 → **1.35.3**, toolchain
      `~> 15.3.0` → **15.3.1** (same pins as `nerves_system_vagus` targets; sync-base will
      require equality later); `mix deps.get`; `.tool-versions` OTP/Elixir aligned with our
      fleet (29.1.2 / 1.20.x). Check Buildroot 2026.08.1 gotchas on his packages (aic8800,
      libmali, librknnrt `.hash` regen, `BR2_TOOLCHAIN_EXTERNAL_GCC_15=y`, linux-firmware
      `LICENSES/` path moves). — DONE: br 1.35.3 (= Buildroot 2026.08.1), toolchain URL 15.3.1-C0D130A + `GCC_15=y`, `~> 15.3.0` dep kept (lock needed `mix deps.update` for 15.3.1), `@github_organization` → bbangert, OTP 29.1.2.
- [x] 0.2 Kernel pin: `nerves_defconfig` `BR2_LINUX_KERNEL_CUSTOM_TARBALL_LOCATION` →
      armbian/linux-rockchip tarball at rkr7.2 HEAD `8585509` (full sha); keep
      `BR2_LINUX_KERNEL_PATCH`, `rockchip_linux` defconfig, fragments and
      `rockchip/rk3576-rock-4d-spi` dts. Update the stale "DEBUG defaults on" comment in
      `linux/rk3576.config`; confirm `CONFIG_MALI_BIFROST*` lines are present there (they are
      the only enabler now). Add `CONFIG_SCSI_UFS_ROCKCHIP=y` explicitly if the defconfig
      ever drops it (verify it's `=y` in `rockchip_linux_defconfig` at rkr7.2). — DONE: pinned 858550966271b1f59897a106bc3f92842ea0e750; UFS_ROCKCHIP/UFSHCD/RKNPU `=y` verified in the defconfig, MALI absent (fragment load-bearing, comment rewritten); dts patch dry-run clean.
- [x] 0.3 GPU blob: `package/libmali/libmali.mk` → `libmali-next` branch,
      `libmali-bifrost-g52-g29p1-gles.so` (+ pkgconfig/headers unchanged), `.hash` regen,
      README table row; drop the "expected compatible" wording. — DONE: libmali-next @bf621d15, sha256 02d42b4a… verified, SONAME already libmali.so.1, NEEDED only libdrm beyond libc; Config.in help updated too.
- [x] 0.4 aic8800: re-pin radxa-pkg/aic8800 to release -10 (2026-10-12) commit; refresh the
      25 copied patches (regenerate the 4 CRLF ones), keep `0017 use-bluez-by-default`;
      verify the 6.1.172 build in 0.6. librknnrt: keep 2.3.2 (or bump to 2.5.0 if the
      `.mk` URL pattern holds) — record choice in scratchpad. — DONE: pinned e9e43ed7 (-10); series 25→29 (7.2/7.3 build, sdio fw path, sprintf overlap), only 0006/0020 need CRLF regen now, 0017 upstream as-is; 29/29 dry-run clean with BR flags. librknnrt stays 2.3.2 (scratchpad).
- [x] 0.5 README: new "UFS boot (this fork)" status rows as **planned**, kernel row →
      rkr7.2; CHANGELOG entry `0.2.0-dev`; `VERSION` → `0.2.0-dev` (tag `v0.2.0` at Phase 2). — DONE: SD row `Replaced`, UFS row `Planned`, dep example → bbangert v0.2.0; Building/Flashing/Boot-flow sections left for Phase 1.
- [x] 0.6 Build the system as-is (still SD layout) natively: `MIX_TARGET=... mix compile`
      → full Buildroot build; prove kernel 6.1.172 + rknpu + bifrost + aic8800 + libmali
      compile. Save `build.log` excerpt (kernel version line, module list) to scratchpad. — DONE: green in 22 min, 6.1.172, all gate symbols + g29p1 strings + 3 aic .ko verified (scratchpad).
- [x] 0.7 PR `ufs-boot` → fork `main` ("Pins: br 1.35.3, rkr7.2, g29p1 libmali, aic8800 -10").
      Reviews + Copilot loop. **STOP.** — DONE: PR #1 on the fork (head aae7916); local code-review 4 fixed / 1 invalid; Copilot round 1 = 1 finding declined as out-of-scope (unbuilt SDIO tree, verbatim vendor patch), 0 open. AWAITING BEN'S MERGE.

Verification: `make` (Buildroot) exits 0; `build/linux-*/.config` has
`CONFIG_SCSI_UFS_ROCKCHIP=y`, `CONFIG_MALI_BIFROST=y|m`, `CONFIG_ROCKCHIP_RKNPU=y`;
`output/target/usr/lib/libmali*.so` strings contain `g29p1-12eac0`; aic8800 `.ko` present.

## Phase 1 — UFS boot chain in the fork (no board) `[system]`

- [x] 1.1 **U-Boot in Buildroot**: `nerves_defconfig` `BR2_TARGET_UBOOT=y`,
      `BR2_TARGET_UBOOT_CUSTOM_TARBALL` (u-boot v2027.01-rc1 → v2027.01 when tagged),
      `BR2_TARGET_UBOOT_BOARD_DEFCONFIG="rock-4d-rk3576"`,
      `BR2_TARGET_UBOOT_CONFIG_FRAGMENT_FILES="${NERVES_DEFCONFIG_DIR}/uboot/ufs.fragment"`,
      `BR2_TARGET_UBOOT_NEEDS_PYLIBFDT=y` (host-swig), `_NEEDS_PYELFTOOLS=y`,
      `_NEEDS_OPENSSL=y`, `BR2_TARGET_UBOOT_FORMAT_CUSTOM` name
      `u-boot-rockchip-spi.bin`, `BR2_TARGET_UBOOT_CUSTOM_MAKEOPTS="ROCKCHIP_TPL=<path>
      BL31=<path>"`. TPL/BL31: Buildroot ships `boot/rockchip-rkbin` (verify in
      2026.08.1: `BR2_TARGET_ROCKCHIP_RKBIN`, `_TPL_FILE`, `_BL31_FILE`) → use it with
      `rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin` + `rk3576_bl31_v1.25.elf`; if absent,
      add a tiny `package/rockchip-rkbin` in the fork pinned to rkbin@3e288fe. Delete the
      committed `uboot/u-boot-rockchip-spi.bin` only after 1.8 proves the built one; keep
      `uboot/rk3576_spl_loader_v1.09.108.bin` (maskrom loader).
- [x] 1.2 `uboot/ufs.fragment` = the proven fragment (facts above) with
      `CONFIG_ENV_SCSI_PART_UUID` = a freshly generated UUID that is ALSO the fwup p1 `guid`
      (one constant, defined once in `fwup_include/fwup-common.conf` and copied into the
      fragment; a `make check`-style script asserts they match).
- [x] 1.3 `uboot/uboot.env`: `boot_targets=scsi`; `nerves_boot` → `scsi scan; load scsi 0:2
      ${kernel_addr_r} ${bootfile}; load scsi 0:2 ${fdt_addr_r} ${fdtfile}`; keep
      `nerves_init`/`nerves_revert` unchanged (only `test/setenv/saveenv`); `root=PARTUUID=`
      stays (both extlinux-*.conf too). Keep `ENVIMAGE_SIZE=131072`. Remove
      `scripts/build-uboot.sh` Docker path or mark it legacy (decide in scratchpad; upstream
      shape favours keeping it documented).
- [x] 1.4 fwup layout (`fwup.conf`, `fwup_include/fwup-common.conf`,
      `fwup_include/provisioning.conf`, `fwup-ops.conf`): GPT p1 env (raw, `guid` = 1.2
      constant, type = generic Linux data or a Nerves-specific GUID), p2 bootfs FAT 256 MiB
      @ 512-off 32768, p3/p4 rootfs 512 MiB, p5 data (f2fs, sized by the image tool, NO
      `expand`); `UBOOT_ENV_OFFSET=2048`, count 256; `NERVES_FW_DEVPATH=/dev/rootdisk0`,
      `NERVES_FW_APPLICATION_PART0_DEVPATH=/dev/rootdisk0p5`; `require-path-on-device`
      → `rootdisk0p3`/`p4`; `fwup-ops` `revert`/`validate`/`status` paths; `complete`
      writes `a.nerves_fw_validated=1` + `nerves_fw_platform=rock_4d`
      (`NERVES_FW_PLATFORM`), `nerves_fw_architecture=arm64`. Offsets MiB-aligned (4096 ×
      LBA = 512 × 8).
- [x] 1.5 `rootfs_overlay/etc/fw_env.config` → `/dev/rootdisk0p1 0x0 0x20000`;
      `rootfs_overlay/etc/erlinit.config`: drop the `/mnt/boot` vfat mount, data mount →
      `/dev/rootdisk0p5:/root:f2fs`, console stays `ttyS0`(verify his value), keep boardid
      source. `post-createfs.sh`: whatever it did for SD env image → env image still needed
      by fwup `uboot-environment` (keep).
- [x] 1.6 `tools/mk_ufs_image.py` (adapted from `nerves_system_dragon_q6a/tools/
      mk_ufs_image.py`): input `fwup -a -t complete -d out.img` (512 GPT), output a 4096-LBA
      image with regenerated primary+backup GPT preserving every partition's unique GUID and
      type, names `env/bootfs/rootfs-a/rootfs-b/data`, 5 partitions, data last and grown to
      `--size` (module capacity) minus backup GPT; refuse if the reader-presented sector
      size matters (document `blockdev --getss`). Unit tests (pytest, `python3 -I`) with a
      synthetic image: GUID preservation, 4096 alignment, backup GPT placement.
- [x] 1.7 `scripts/flash-ufs.sh` runbook helper: build `.fw` → `.img` → `mk_ufs_image.py`
      → `dd bs=4M conv=fsync` to the reader device (refuses non-removable / size mismatch);
      README "Flashing (UFS module)" + "One-time: U-Boot to SPI NOR via maskrom
      (`rkdeveloptool db rk3576_spl_loader_v1.09.108.bin; rkdeveloptool wl 0
      u-boot-rockchip-spi.bin`)" + "Reflash from Linux: `flashcp`".
- [x] 1.8 Full native system build; verify `images/u-boot-rockchip-spi.bin` produced,
      `binman ls` map recorded (real FIT end → free NOR), fragment symbols in
      `build/uboot-*/.config`; `.fw` builds; `mk_ufs_image.py` run on the `.fw` output
      passes `sgdisk -v` / `gdisk -l` with 4096 sector size (`losetup -b 4096`).
- [x] 1.9 PR → fork `main` ("UFS boot: mainline U-Boot in Buildroot, env partition, 4Kn
      image tool"). Reviews + Copilot. **STOP.** — DONE: PR #3 MERGED after 4 Copilot rounds (r4 clean). Deviations: U-Boot v2027.01-rc1 (v2026.10 lacks XMC fix); rkbin = his proven DDR v1.12/BL31 v1.24 committed (BR rkbin too old); legacy blob + build-uboot.sh deleted; boot disk found by env UUID (nerves_find_disk) not scsi 0; fw_env via whole disk @1 MiB; bootfs GPT legacy-bootable attr (bootflow scan fallback); check-env-config.sh (UUID×3/size×4/offset); 4Kn loop-device parse impossible in devcontainer → board. See scratchpad.

Verification: build exits 0; `strings images/u-boot-rockchip-spi.bin | grep -c
ENV_SCSI_PART_UUID`-equivalent (env default text contains `boot_targets=scsi`); `fwup -i
*.fw -m` shows platform `rock_4d`; `losetup -b 4096` + `gdisk -l` lists p1..p5 at the planned
MiB starts with the same GUIDs as the 512 image; pytest green.

## Phase 2 — Device bring-up + system release (ONE board) `[device]`

- [ ] 2.1 Board intake: serial console (UART0 debug header; 1.5 Mbaud per Radxa docs —
      verify), read silkscreen rev → expect NOR chip; power via USB-C PD. Record rev,
      module capacity/model, reader `blockdev --getss --getpbsz` in scratchpad.
- [ ] 2.2 Maskrom: hold MASKROM, `rkdeveloptool ld` → `db` loader → `wl 0
      u-boot-rockchip-spi.bin` → `rd`. Serial shows TPL/SPL/U-Boot v2027.01 banner, SPI NOR
      probed (`sf probe` / boot log names the chip → XMC or not; record).
- [ ] 2.3 Module: write the 4Kn image via reader (1.7), seat, boot. U-Boot: `scsi scan`,
      `scsi info` → which `scsi N` is the user LUN (expect 0; if not, fix `load scsi N:2` in
      1.3 and re-run), env load OK (`Loading Environment from SCSI... OK`), extlinux boots
      slot A, kernel 6.1.172, `/dev/rootdisk0p5` mounted f2fs, `fw_printenv` works,
      `Nerves.Runtime.KV.get("nerves_fw_active") == "a"`, `nerves_fw_validated=1`.
- [ ] 2.4 Negative/boot-robustness: cold boot ×3; boot with no module → U-Boot falls to USB
      cleanly (no hang); boot time to IEx recorded (timestamps, not attempt counts).
- [ ] 2.5 A/B: `mix upload` (or `fwup -a -d /dev/rootdisk0 -t upgrade`) → slot B boots;
      `Nerves.Runtime.revert` → A; forced revert test: upgrade to B, do NOT validate, power
      cycle → U-Boot `nerves_revert` path returns to A (bootcount/`upgrade_available` logic).
      Verify `saveenv` writes only p1 (compare p1 before/after, GPT intact).
- [ ] 2.6 Peripherals: Ethernet (DHCP), WiFi (`wlan0` via aic8800_fdrv, STA connect,
      `a69c:8d81` re-enum), BT `hci0` present (`bluetoothctl` not in base — just hci up),
      HDMI console, RTC, watchdog (heart), GPU (`kmscube` 3 s run on `/dev/dri/card0` with
      the g29p1 blob: no `Failed to open`/version mismatch in dmesg), NPU (`/dev/rknpu`,
      `rknn_server`-less check: `librknnrt` version query via a tiny C or the Radxa
      `rknn_benchmark` if packaged — record what "NPU works" means here and how it's shown).
      Thermals under a 2-min stress.
- [ ] 2.7 Fix-ups from 2.3–2.6 as small PRs to the fork (each with the gate re-run).
- [ ] 2.8 README hardware table updated with measured results (UFS → Yes, SD → "not used
      by this fork", NOR chip rev note); CHANGELOG `0.2.0`; `VERSION=0.2.0`. PR → fork main.
      **User tags `v0.2.0`**; fork CI publishes the system artifact (whatever 0.0 found; if
      his CI doesn't release, add `.github/workflows/release.yml` modelled on
      nerves_system_dragon_q6a's). Verify the artifact URL `mix` can fetch. **STOP.**

Verification: all 2.3–2.6 items pass on the board with evidence pasted into scratchpad
(serial excerpts, `scsi info`, `fw_printenv`, dmesg lines); `v0.2.0` release has the
`.tar.gz` system artifact.

## Phase 3 — nerves_system_vagus `rock_4d/` `[system]`

- [ ] 3.1 `git subtree add --prefix rock_4d/base https://github.com/bbangert/
      nerves_system_rock_4d v0.2.0 --squash`; `Makefile`: `BASE_TARGETS += rock_4d`,
      `BASE_REPO_rock_4d`, (lines 25/28/30); `make base-pull BASE=rock_4d REF=v0.2.0` works.
- [ ] 3.2 Product layer: `rock_4d/nerves_defconfig.fragment`, `Config.in.fragment`,
      `erlinit.config.fragment`, `external.mk`, `mix.exs` (package
      `nerves_system_vagus_rock_4d`? — follow dragon_q6a's naming), `VERSION`, `CHANGELOG`,
      modelled on `dragon_q6a/` (diff dragon_q6a fragments vs its base to list exactly what
      the product layer adds: BlueZ + D-Bus + `main.conf`, podman/netavark/crun stack,
      shared packages, Vagus erlinit/console, hwdebug fragment). `make sync TARGET=rock_4d`
      generates the three files; `make check` + `make check-base-pristine` pass.
- [ ] 3.3 `.github/workflows/build.yml` matrix (line 57) += `rock_4d`; cache key already
      includes `base/**`. Native full build of `rock_4d` in the devcontainer.
- [ ] 3.4 Device smoke of the product system on the board (optional but cheap: flash the
      nerves_system_vagus `rock_4d` build via the 1.7 path, verify BlueZ `hci0` +
      `bluetoothctl show`, podman `info` on f2fs `/root`).
- [ ] 3.5 PR → nerves_system_vagus main. Reviews + Copilot. **User merges + tags `v0.9.0`**
      (verify `VERSION` files at the tag BEFORE the build uploads — v0.8.0 lesson). Confirm
      11+1 artifacts. **STOP.**

Verification: CI green incl. `check-base-pristine`; release `v0.9.0` has the `rock_4d`
artifact.

## Phase 4 — vagus wiring + device gate + release `[app]`

- [ ] 4.1 `apps/vagus/mix.exs` + `apps/vagus_platform/mix.exs` `@all_targets` += `:rock_4d`;
      path dep block (`apps/vagus_platform/mix.exs:59-73`) += rock_4d system (path in dev,
      release tag in CI); `.mise.toml` target list; `config/rock_4d.exs` (copy
      `config/dragon_q6a.exs`, adjust: console, `core_container` cpuset/RAM if any,
      boardid, WiFi regulatory, `:native_addon_slugs` same as others); `config/target.exs`
      any `case target` lists that enumerate boards (grep `:dragon_q6a` for every site).
- [ ] 4.2 `.github/workflows/release.yml` matrix += `rock_4d` (+ `-agent` flavor as the
      other two targets have); `SYSTEM_RELEASE_TAG` → `v0.9.0`; `ci.yml` checkout ref for
      the unused-lock step; `mix.lock` update.
- [ ] 4.3 Runtime checks: `Vagus.Runtime.Host` picks `fast` on the Rock 4D (RAM ≥ 2 GiB —
      record the board's RAM); `Vagus.Provisioner` 4Kn gate + `p5` path hold (no code
      change expected — assert via test with `logical_block_size=4096` fixture if not
      already covered); `/os/update` asset name `vagus_rock_4d.fw`; `Vagus.Dist` cookie;
      `scripts/device/ws-proxy-gate.sh` target-agnostic.
- [ ] 4.4 Local build `MIX_TARGET=rock_4d mix firmware` → `.fw` → 4Kn image → flash via
      reader → board boots Vagus; first-boot provisioning installs HA Core (podman pull on
      f2fs, fast profile spool on disk), HA onboarding reachable, Vagus panel opens, Core
      update refused above ceiling (sanity), WiFi via HA network settings, BT scan from HA
      (BlueZ), `/os/update` dry path (`Vagus.OS.Update` check against the release asset
      once 4.6 exists → re-run after release).
- [ ] 4.5 PR → vagus main. Reviews + Copilot. **User merges.**
- [ ] 4.6 Release PR `chore/release-0.14.0` (version bump + release body: new target, UFS
      flashing runbook link, known limits: single env copy, no SD). **User tags**; watch
      the run: 7 assets (5 + `vagus_rock_4d.fw` + `-agent`). Board OTA from the local
      build to the released 0.14.0 via `/os/update`; validated across reboot. **STOP.**

Verification: `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix test`
(umbrella root), `mix credo --strict`, `mix sobelow`, argus baseline, `mix dialyzer`
(197/129 baseline) all as CI; release run green with 7 assets; board on 0.14.0.

## Risks / self-check (deep)

1. **What would make this plan wrong?** (a) `ENV_IS_IN_SCSI` on U-Boot cannot reach the
   LUN at env-load time (UFS reset/probe timing) → fall back to `ENV_IS_IN_SPI_FLASH` at
   0xc00000 + an `fw_setenv`-based slot flip (decision 6 alternative; fwup can't write MTD).
   (b) The user LUN is not `scsi 0` → 1.3 gets the index from 2.3; env is unaffected (UUID).
   (c) U-Boot's 512-BPB-FAT-on-4Kn read path is slow or buggy for a 40 MB kernel → shrink
   kernel (modules) or move Image/dtb into a raw partition read via `scsi read` + `bootm`.
   (d) libmali g29p1 blob lacks a `-gbm` variant: the unsuffixed `-gles` file has GBM
   symbols; if kmscube fails, test the `libmali` branch g24p0 as a stopgap (UNVERIFIED).
2. **What's the cheapest test that de-risks the most?** 2.2 + 2.3: U-Boot in NOR + the first
   UFS env load/extlinux boot. Everything after is known territory (Q6A/Rubik 4Kn, Vagus).
3. **What did we assume without evidence?** That `boot/rockchip-rkbin` exists in Buildroot
   2026.08.1 with rk3576 files (1.1 verifies; fallback package planned); that `rkdeveloptool`
   on the devcontainer host can see the board over USB (user's host may be needed); the
   board's RAM size and module capacity; that his fork CI releases artifacts (0.0 checks).
4. Single env copy: a torn `saveenv` → default env → extlinux A without revert on that boot.
   Accepted (decision 6); noted in README.
5. Upstream shape: the fork REPLACES SD with UFS in `fwup.conf`. Re-adding SD as a build
   variant is upstream-time work (out of scope), recorded in scratchpad.

## Verification summary

| Phase | Gate |
|---|---|
| 0 | Buildroot build green on rkr7.2; libmali g29p1 strings; aic8800 .ko |
| 1 | `u-boot-rockchip-spi.bin` from Buildroot with fragment; 4Kn image passes `gdisk -l` (4096); pytest |
| 2 | Board: UFS env load, extlinux A, A/B + forced revert, peripherals incl. GPU/NPU; `v0.2.0` artifact |
| 3 | nerves_system_vagus CI + pristine check; `v0.9.0` with rock_4d artifact |
| 4 | vagus CI gates; release 0.14.0 with 7 assets; board OTA'd + validated |

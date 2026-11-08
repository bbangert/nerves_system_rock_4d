# Interview — rock-4d-target

**Topic:** Add the Radxa ROCK 4D (Rockchip RK3576) as a Vagus target.
**Date:** 2026-11-08 (resumes the target parked 2026-08-05; the earlier approved plan file is gone, its locked decisions survive in memory)

## Coverage

| Dim | Score | Notes |
|-----|-------|-------|
| What | 2 | New full Vagus target `rock_4d`, same shape as dragon_q6a / rubik_pi3 (base system repo + product layer) |
| Why | 2 | Third SBC family; RK3576 NPU/GPU; 8 GB-class board at a lower price than the Q6A |
| Scope | 1 | UFS module is THE boot/storage medium (microSD ruled out 2026-08-05, eMMC physically unsupported). Kernel choice OPEN: vendor 6.1 / vendor 6.12 / mainline LTS 6.18 / **non-LTS mainline (user asked to add)** |
| Where | 1 | New base repo `nerves_system_rock_4d`-style + `rock_4d/` in nerves_system_vagus + vagus_platform target wiring + release matrix |
| How | 1 | Starting point isaiahdw/nerves_system_rock_4d (SD boot, vendor 6.1, no UFS integration; `mainline` branch on 6.18.40). U-Boot lives in SPI NOR (one-time maskrom flash) |
| Edge | 1 | 4Kn UFS vs fwup 512-LBA GPT (Q6A lesson); U-Boot must read env/kernel from UFS; NPU driver availability per kernel; AIC8800 out-of-tree driver per kernel version |

Total: 8/12 (initial; see the post-interview table at the end)

## Answers so far

1. **Kernel:** "Can we also research non-LTS mainline? I'm going to be using UFS so that has to work as the boot medium." → research all four directions; UFS boot is a hard requirement that gates the kernel choice.

## Facts gathered (2026-11-08)

- isaiahdw/nerves_system_rock_4d: `main` = armbian `rk-6.1-rkr5.1` (July 2026), nerves_system_br 1.34.0, full NPU (rknpu 0.9.8 + librknnrt 2.3.2) + vendor Mali/libmali, 25 aic8800 patches, U-Boot in SPI NOR, SD boot, "UFS modules: No — kernel support present; boot/storage integration not done". `mainline` branch = 6.18.40, no NPU, panfrost kernel-only (no Mesa: "Buildroot's panfrost requires LLVM"), no analog audio.
- armbian/linux-rockchip now has `rk-6.12-rkr1` (6.12.69, commit 2026-11-04) with `rk3576-rock-4d.dts` + `rk3576-rock-4d-spi.dts`; `rk-6.1-rkr7.2` is at 6.1.172 (2026-11-04).
- Mainline has `rk3576-rock-4d.dts` (+ cam4k overlay); dts landed 6.15, USB/WiFi/HDMI-audio completed 2025-07; README claims ethernet/PCIe/USB/HDMI-audio/UFS complete ~6.17.
- Our stack already runs non-LTS mainline on the Q6A (7.2.x) with nerves_system_br 1.35.3 / Buildroot 2026.08.1.

## Open questions

- UFS boot chain: does U-Boot (vendor and/or mainline) initialise the RK3576 UFS host and read a GPT + FAT bootfs from it? Where does the Nerves U-Boot env live when there is no SD?
- UFS module logical block size (4Kn?) → fwup GPT/partition offsets, the Q6A 4Kn lessons.
- Non-LTS mainline: NPU (rocket) RK3576 status, panfrost + Mesa feasibility in Buildroot, aic8800 driver build on 7.x.
- Vendor 6.12: rknpu/libmali/librknnrt version pairing, UFS driver maturity.

## Research cycle 1 (2026-11-08) — see research/kernel-ufs-options.md, research/codebase-scan.md

- **Kernel is not the UFS gate.** All four lines (vendor 6.1 rkr7.2, vendor 6.12 rkr1, 6.18 LTS, 7.3 stable) have the RK3576 UFS driver and `rk3576-rock-4d.dts` enables it.
- **U-Boot is the gate.** Mainline U-Boot: Rockchip UFS driver v2026.01; ROCK 4D UFS boot enabled in `rock-4d-rk3576_defconfig` only in v2026.07; XMC SPI-NOR boards (e.g. V1.12) need `SPI_FLASH_XMC` (v2027.01-rc1). isaiahdw's committed blob is v2026.01 → cannot boot UFS. Radxa vendor U-Boot `next-dev-v2024.10` `rock-4d-spi` has UFS + XMC.
- **Env placement without SD:** mainline `ENV_IS_IN_SCSI` only at the start of a GPT partition (no raw offset) or `ENV_IS_IN_SPI_FLASH`; vs our EDK2/GRUB targets where slot selection lives in grubenv. A/B design decision for the plan.
- **Radxa UFS module is 4Kn** (Radxa ships a 4096-byte "UFS image"); fwup is 512-byte throughout → the Q6A `tools/mk_ufs_image.py` approach (regenerate GPT for 4096; MiB-aligned; no expand-data on 4Kn) applies.
- **NPU:** only vendor kernels (rknpu 0.9.8 + librknnrt). Mainline rocket = RK3588 only; RK3576 RFC v2 (Jul 2026) "inference not correct yet", Mesa MR !43804 open.
- **GPU:** vendor kbase g29p1 + libmali blob (A/B); panfrost on C/D needs target LLVM on Buildroot 2026.08 (host-llvm only on BR master 2026-10-24).
- **WiFi/BT:** no in-tree USB AIC8800 driver anywhere; radxa-pkg/aic8800 OOT has fixes through 7.4; builds on 6.12/6.18/7.3 UNVERIFIED.
- **Horizon:** 7.2 EOL 2026-11-01 (our Q6A line); non-LTS ≈ 11 weeks/release; 6.12/6.18 LTS to Dec 2028; 6.1 to Dec 2027; vendor trees lag upstream stable (6.1.172 vs .192; 6.12.69 vs .116).
- **Port shape (codebase-scan):** new tagged base repo → subtree into nerves_system_vagus (Makefile BASE_TARGETS, build.yml matrix), `config/rock_4d.exs` required, `@all_targets` in both mix.exs, release.yml matrix + SYSTEM_RELEASE_TAG, `NERVES_FW_PLATFORM=rock_4d`; GRUB pieces replaced by extlinux/boot.scr + env design; data stays `rootdisk0p5`; complete flash must set `a.nerves_fw_validated=1`.

## Answers (cont.)

2. **Hardware on hand:** two ROCK 4D boards, never booted; SPI NOR chip / board revision unknown (read the silkscreen rev, or `dmesg | grep spi-nor` after the first boot of any image). Two boards → one can stay on the Radxa stock image as a reference/bench board while the other is brought up.

## Research cycle 2 (2026-11-08) — research/uboot-ufs-chain.md, research/kernel-line-feasibility.md, research/comparison.md

- Mainline U-Boot v2027.01-rc1 `rock-4d-rk3576_defconfig`: UFS/SCSI/SPL_UFS + XMC/Macronix NOR, SPI image via binman (rkbin DDR v1.13 + BL31 v1.25, or upstream TF-A); **no `ENV_IS_IN_*` set** (falls back to NOWHERE); SPL order sdmmc→sdhci→ufshc; `boot_targets` includes scsi → extlinux from UFS works. BootROM confirmed FSPI0 → UFS → USB (SD never).
- 4Kn: SCSI/GPT/ext4/env-in-SCSI take blksz from the device; **FAT needs `CONFIG_FS_FAT_HANDLE_SECTOR_SIZE_MISMATCH=y`** (v2026.07+, off by default) or a 4096-sector FAT.
- Env/A-B: (a) SPI NOR @0xc00000 — fwup can't write MTD; (b) GPT env partition on UFS (`ENV_IS_IN_SCSI`, UUID or `ENV_SCSI_HW_PARTITION`), fwup `uboot_setenv` works, single copy; (c) fwup rewrites extlinux — no auto-revert.
- Radxa UFS image: 4K-sector image, p1 128 MiB config, p2 ESP, p3 rootfs, extlinux in rootfs, no env in SPI; flash via module reader or SD-boot + dd.
- Kernel lines: A and B have identical rknpu 0.9.8 + kbase g29p1 (B = no feature gain, unproven on Rock 4D); Armbian builds Rock 4D on vendor 6.1 and mainline 7.3; Radxa official = 6.1.84; mainline NPU usable ≈ mid-2027; panfrost on BR 2026.08 = target LLVM+clang (~190 MB); Vagus grants no /dev/dri today; Q6A non-LTS cost = one forced bump (7.1→7.2) + aic8800 re-pin, 7.2 now EOL.
- Baseline comparison table in research/comparison.md.

3. **Hard requirement:** full NPU and GPU. → Mainline lines C/D are OUT. Only the Rockchip vendor BSP lines remain (6.1 rkr7.2 or 6.12 rkr1; rknpu 0.9.8 + kbase g29p1 in both).

4. **Kernel DECIDED:** Rockchip vendor BSP 6.1, pin armbian/linux-rockchip `rk-6.1-rkr7.2` (6.1.172; board dts added 2026-08-05). Carry forward isaiahdw's Nerves DTS fixup patch (re-check against rkr7.2), rknpu 0.9.8 + librknnrt (2.3.2 or 2.5.0), kbase g29p1 → pair a g29p1 G52 libmali blob (JeffyCN `libmali-next`; g24p0-on-g29p1 UNVERIFIED fallback). Later move to 6.12 rkr1 only after someone proves it on the board.

5. **Repo strategy DECIDED:** `bbangert/nerves_system_rock_4d` = a GitHub **fork of isaiahdw/nerves_system_rock_4d**, not a fresh repo, so the UFS work can go back upstream as a PR once it boots. Implications: keep his layout/history; make UFS additive (keep SD boot working) and keep changes upstream-shaped; our base-repo conventions (sync-base fragments etc.) stay in nerves_system_vagus's subtree layer, not in the fork; kernel pin bump to rkr7.2 is itself an upstreamable commit.

6. **Env / A-B DECIDED:** Nerves U-Boot env in a small dedicated GPT partition at the start of the UFS LUN (`ENV_IS_IN_SCSI`, selected by the partition's UNIQUE GUID via `CONFIG_ENV_SCSI_PART_UUID` — not the type GUID, not the name; fwup sets p1 `guid` to the same value — corrected by research cycle 3); fwup writes it via `uboot_setenv` at the partition's fixed LBA (Q6A 4Kn precedent); `fw_env.config` points at that partition, offset 0; keep isaiahdw's `nerves_init`/`nerves_boot` revert logic unchanged. Single copy (no redundant env) accepted. Upstream has no forks/PRs/issues; user creates the fork.

7. **U-Boot DECIDED:** mainline U-Boot v2027.01-rc1 (move to the v2027.01 release tag when it lands), `rock-4d-rk3576_defconfig` + our fragment (`ENV_IS_IN_SCSI` + env partition selection, `FS_FAT_HANDLE_SECTOR_SIZE_MISMATCH` or a 4096-sector FAT, keep XMC/Macronix NOR drivers), SPI image via binman with rkbin DDR v1.13 + BL31 v1.25 (upstream TF-A as the alternative). Extends his `scripts/build-uboot.sh` rather than replacing it.

8. **Upstream PRs are OUT of scope** for this work (they come later). The fork still keeps changes upstream-shaped (additive UFS beside SD boot, his layout kept) so a PR stays possible, but no PR is opened as part of any phase here.

9. **Test hardware: ONE ROCK 4D board** for this work (the second board is not part of it). All gates are single-board.

10. **Deliverable DECIDED: full Vagus target in ONE plan** — from the fork through nerves_system_vagus `rock_4d/` (subtree of the fork), vagus_platform wiring (`@all_targets`, `config/rock_4d.exs`, `NERVES_FW_PLATFORM=rock_4d`), release matrix (`vagus_rock_4d.fw` + agent flavor), to a released firmware running on the one board. The tagged system release is an intermediate milestone inside the plan.

11. **Flashing DECIDED:** UFS module in a USB reader on the host (Radxa's documented path): write the 4Kn image with fwup/dd, seat the module, power on. U-Boot goes to SPI NOR via maskrom (`rkdeveloptool`) once; later U-Boot updates via `flashcp` from Linux. SD card not used.

## Coverage after interview (2026-11-08)

| Dim | Score |
|-----|-------|
| What | 2 — full Vagus target `rock_4d` from a fork of isaiahdw/nerves_system_rock_4d |
| Why | 2 |
| Scope | 2 — UFS-only boot, NPU+GPU required, vendor 6.1 rkr7.2, one board, no upstream PRs, one plan |
| Where | 2 — fork repo + nerves_system_vagus subtree + vagus_platform + release matrix |
| How | 2 — mainline U-Boot v2027.01-rc1 in SPI NOR, env in a GPT partition on UFS, 4Kn image, module reader flashing |
| Edge | 2 — 4Kn FAT mismatch, XMC NOR revision, kbase g29p1 blob pairing, aic8800 pin, single env copy, no expand-data on 4Kn |

Total: 12/12

## Research cycle 3 (2026-11-08) — research/uboot-dry-build.md, research/kernel-rkr72.md, research/fwup-4kn-layout.md

- **U-Boot v2027.01-rc1 + our fragment configures and compiles** (TPL/SPL/U-Boot proper built with the Nerves 15.3 toolchain; rkbin DDR v1.13 + BL31 v1.25). Final binman packing failed only because this host lacks `swig` (pylibfdt) → the SPI image must be built where swig exists: Buildroot `BR2_TARGET_UBOOT` (host-swig handled) or isaiahdw's Docker `scripts/build-uboot.sh`. Fragment that survived olddefconfig: `ENV_IS_IN_SCSI`, `ENV_SCSI_PART_UUID=<p1 unique GUID>`, `ENV_SIZE=0x20000`, no redundant env, `FS_FAT_HANDLE_SECTOR_SIZE_MISMATCH`, XMC+Macronix+GigaDevice+Winbond NOR. Est. ~14.4 MiB NOR free (unmeasured).
- SPL order `same-as-spl, sdmmc, sdhci, ufshc`; nothing scans SCSI at init → env load does the first scan; add explicit `scsi scan` in `nerves_boot`. `scsi 0` = LUN0 UNVERIFIED (UFS modules expose several LUNs); use `root=PARTUUID=` and load from `scsi 0:2` after `scsi info` confirms.
- **Kernel rkr7.2:** his DTS fixup patch applies with zero fuzz (mmc alias + wdt halves still needed); `rk3576-rock-4d-spi` dts + `rockchip_linux` defconfig exist; UFS (`reset-gpios` present) and rknpu 0.9.8 (=y) unchanged; kbase g25p0 → **g29p1-12eac0** and `MALI_BIFROST` dropped from defconfig (his `rk3576.config` is now the only enabler); **`libmali-next` `libmali-bifrost-g52-g29p1-gles.so` embeds exactly `g29p1-12eac0`** (Arm EULA; has GBM/EGL symbols); librknnrt 2.5.0 (2026-10-20) same layout, min driver not extractable; aic8800 dkms on 6.1.172 untested.
- **fwup is 512-byte everywhere** (v1.17.1): `.fw` + on-device A/B tasks work on 4Kn (byte-offset I/O), but `gpt_write` hardcodes 512 geometry → regenerate the GPT for 4096 (Q6A `mk_ufs_image.py`, needs its hardcoded names/5-partition rule adapted) and **never run `fwup -d /dev/sdX` on the module**. FatFs fixed at 512 → bootfs stays a 512-BPB FAT, hence the U-Boot mismatch option; Linux probably won't mount it → drop the `/mnt/boot` mount (Q6A never mounts its FAT). `uboot_env` (Elixir) is byte-offset pread → fine. erlinit gives `rootdisk0p5` for `/dev/sda5`.
- **Layout (4096 LBAs, MiB-aligned):** p1 env 1 MiB @1 MiB (raw; fwup env offset 2048×512, count 256; `fw_env.config` `/dev/rootdisk0p1 0x0 0x20000` or `/dev/rootdisk0 0x100000 0x20000 0x1000 32`), [2–16 MiB unallocated], p2 bootfs FAT 256 MiB @16, p3 rootfs-a 512 @272, p4 rootfs-b 512 @784, p5 data @1296 grown at image build (no `expand-data` on 4Kn; Provisioner hardcodes p5). `complete` must set `a.nerves_fw_validated=1`.
- Open: reader's presented sector size (`blockdev --getss`), module capacity (backup GPT), single env copy torn-write → default env → extlinux without revert, UFS probe time at env load.

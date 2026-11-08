# Changelog

## v0.2.0-dev

In progress. This fork moves boot from the SD card to a Radxa UFS module
(the ROCK 4D BootROM boots SPI NOR, then UFS, then USB, never SD); SD boot
is replaced rather than kept alongside. The change is in this branch,
build-proven only, pending hardware bring-up.

UFS boot:

- Mainline U-Boot v2027.01-rc1 is built inside Buildroot
  (`images/u-boot-rockchip-spi.bin`, `uboot/ufs.fragment`), with the DDR
  TPL and BL31 blobs committed under `uboot/rkbin/`. Flashed once to the
  SPI NOR over maskrom; about 14.4 MiB of the NOR stays free.
- The U-Boot env is the first 128 KiB of GPT p1 (`env`), found by p1's
  unique GUID (`CONFIG_ENV_IS_IN_SCSI`). `scripts/check-env-uuid.sh` fails
  the build if fwup and the U-Boot fragment drift. Single env copy: a torn
  `saveenv` falls back to the default env and an extlinux boot.
- New layout for the 4096-byte-sector module: env, bootfs (FAT), rootfs-a,
  rootfs-b, data (f2fs). `/mnt/boot` is gone; Linux never mounts the
  512-byte-BPB FAT bootfs.
- fwup's GPT writer is 512-only, so modules are written with
  `scripts/flash-ufs.sh` (`fwup -d file.img`, `tools/mk_ufs_image.py`, dd).
  Do not `fwup -d`/`mix burn` straight to the module. `expand-data` is
  unavailable; the image tool sizes `data` to the module. On-device OTA is
  unchanged.
- `complete` sets `a.nerves_fw_validated=1`; upgrade tasks clear the target
  slot's flag so a stale `1` cannot hide an unvalidated upgrade.
- The SD slot is unused. The `mmc0` alias half of the dts patch is now
  legacy (harmless); the watchdog half is still required.
- Not yet verified on hardware: `scsi 0` being the user LUN, UFS probe at
  env-load time, and NOR chip variants.

Pin bumps:

- nerves_system_br 1.34.0 -> 1.35.3 (Buildroot 2026.05.x -> 2026.08.1),
  toolchain 15.3.0 -> 15.3.1, OTP 29.0.3 -> 29.1.2.
- Kernel: armbian `rk-6.1-rkr5.1` (6.1.115) -> `rk-6.1-rkr7.2` (6.1.172).
  rkr7.2 dropped `CONFIG_MALI_BIFROST` from `rockchip_linux_defconfig`, so
  `linux/rk3576.config` is now the only thing enabling Mali. Board dts
  patch is unchanged.
- libmali: g24p0-gbm -> `libmali-bifrost-g52-g29p1-gles.so` (JeffyCN/mirrors
  `libmali-next`), which matches the kernel's kbase DDK (g29p1-12eac0).
- aic8800: radxa-pkg release -7 -> -10; patch series grew from 25 to 29.
- librknnrt stays at 2.3.2: the rknpu driver is still 0.9.8, the proven pair.

## v0.1.1

Firmware validation fixes found during hardware testing:

- The ops.fw `validate` task no longer writes `upgrade_available`/
  `bootcount` (U-Boot bootcount-feature variables this system doesn't
  use). nerves_runtime's `firmware_validation_status/0` consults
  `upgrade_available` before `nerves_fw_validated`, so a stale value
  made unvalidated firmware self-report as validated while U-Boot's
  revert logic (which reads `nerves_fw_validated`) would still revert
  it.
- Upgrade and validate tasks now unset those variables, so boards that
  ran the v0.1.0 ops.fw self-heal on their next upgrade.
- Docs: clarified SD-vs-SPI boot roles, the RTC battery connector, and
  added a pointer to the experimental mainline-kernel branch.

## v0.1.0

Initial release. Verified on hardware 2026-07-26: full boot on the factory
(Radxa) SPI bootloader via the extlinux path, all subsystem checks passing
(ethernet, onboard WiFi/BT, GPU, HDMI, watchdog, RTC, audio, app
partition, env).

Hardware support at release:

- Boot: mainline U-Boot v2026.01 (`rock-4d-rk3576_defconfig` + rkbin DDR
  init/BL31) in the onboard SPI NOR — the ROCK 4D boot ROM cannot boot from
  SD, so the SPI flash step is one-time provisioning (see `uboot/README.md`).
  Nerves U-Boot-environment A/B slots on the SD card with automatic revert,
  delta firmware updates (fwup >= 1.12.0 on device), extlinux fallback path.
- Kernel: armbian/linux-rockchip `rk-6.1-rkr5.1` pinned by commit SHA,
  in-tree `rk3576-rock-4d-spi` device tree, `rockchip_linux_defconfig` +
  Nerves fragment. One board dts patch
  (`linux/0001`): enable the watchdog for nerves_heart, and alias `mmc0`
  to the SD card so it enumerates as `/dev/mmcblk0` (the vendor dtsi
  aliases mmc0 to the disabled eMMC).
- Ethernet: GbE on gmac0 with RTL8211F PHY (`CONFIG_REALTEK_PHY` added on
  top of the vendor defconfig, which lacks it).
- Display: HDMI on VOP with the framebuffer console enabled; Mali G52 MC3
  via vendor kmod + libmali (EGL/GLES/GBM), kmscube smoke test. No UI
  toolkit ships in the system — the application brings its own DRM/KMS
  stack; eudev + libinput for USB input.
- Audio: ES8388 codec (headphone jack) and HDMI audio via ALSA.
- SPI NOR exposed as the `loader` mtd + flashcp for on-device bootloader
  updates.
- Watchdog-backed heart, HYM8563 RTC, USB3/USB2 hosts, USB gadget ethernet,
  f2fs application partition.

- WiFi/BT: onboard Quectel FCU760K (AIC8800D80, USB) via the out-of-tree
  radxa-pkg/aic8800 driver + firmware (`package/aic8800`, Radxa's full
  patch series applied); wlan0 + BlueZ hci0, modalias-autoloaded.

- NPU: librknnrt 2.3.2 runtime and C headers matching the in-kernel
  RKNPU driver (0.9.8); models are built on the host with rknn-toolkit2.

Not yet supported: PCIe/NVMe (untested), UFS modules, MIPI DSI/CSI.

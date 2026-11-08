# ROCK 4D Phase 2 bring-up runbook

Phases 0 and 1 (fork pins, UFS boot chain) are merged on `main`. Everything
below is build-proven only; nothing has run on a board yet. Plan, interview
and the decision/dead-end scratchpad are in `plan/`.

## Binaries

Attached to the `bringup-0.2.0-dev` prerelease on this fork:

| File | sha256 |
|---|---|
| `rock4d_bringup.fw` | dea5e017635abb820eda4765b2871a0ac1919542b2c1791c0e714c992a956382 |
| `u-boot-rockchip-spi.bin` | 74ded6eceefa5e658b71a0ba36bbba5b1297687ee8513c9fc7c6f56f875bb8d9 |
| `rk3576_spl_loader_v1.09.108.bin` | 3706ce514b9115667661faedd550fd00136be1b35d08024a87f179133e9c07ac |
| `nerves_system_rock_4d-portable-0.2.0-dev-A831C54.tar.gz` | system artifact, for rebuilding the `.fw` |

The prebuilt `.fw` only trusts the SSH keys of the machine that built it.
To get SSH access from another machine, rebuild with your own keys
(`config/target.exs` reads `~/.ssh/id_ed25519.pub` and `id_rsa.pub`):

```
mkdir -p ~/rock4d-system && tar -xzf nerves_system_rock_4d-portable-0.2.0-dev-A831C54.tar.gz -C ~/rock4d-system
cd bringup && export MIX_TARGET=rock_4d NERVES_SYSTEM=~/rock4d-system
mix deps.get && mix firmware   # -> _build/rock_4d_dev/nerves/images/rock4d_bringup.fw
```

## 1. SPI NOR (one time, maskrom)

Hold MASKROM, plug the upper USB-C (OTG) port into a Linux host with `rkdeveloptool`:

```
rkdeveloptool ld
rkdeveloptool db rk3576_spl_loader_v1.09.108.bin
rkdeveloptool cs 9
rkdeveloptool wl 0 u-boot-rockchip-spi.bin
rkdeveloptool rd
```

## 2. UFS module (USB reader, needs fwup + python3)

From a checkout of this repo:

```
sudo blockdev --getss --getpbsz --getsize64 /dev/sdX   # record these
sudo scripts/flash-ufs.sh rock4d_bringup.fw /dev/sdX
```

The script regenerates the GPT at 4096-byte sectors (`tools/mk_ufs_image.py`)
and refuses a device that is mounted or held.

## 3. Power up

Seat the module, Ethernet on the LAN, UART0 console on header pins 8 (TX),
10 (RX), 6 (GND) at 1500000 8N1, power via USB-C PD. The board answers as
`rock4d.local` (mDNS) over DHCP.

From the serial log, capture: U-Boot banner, the `sf probe` NOR chip name,
`Loading Environment from SCSI... OK`, which SCSI device `nerves_find_disk`
picked, and the kernel's GPT parse of the UFS LUN.

## 4. Checks over SSH (plan tasks 2.3 to 2.6)

- 2.3 env loaded from SCSI; correct LUN found by the env-partition UUID;
  slot A booted kernel 6.1.172; f2fs data on `rootdisk0p5`;
  `fw_printenv` shows `a.nerves_fw_validated=1`; kernel sees 4096-byte sectors.
- 2.4 robustness: cold boots, env survives writes from Linux.
- 2.5 A/B upgrade, manual revert, forced revert across a power cycle.
- 2.6 Ethernet, WiFi/BT (aic8800), GPU (kmscube), NPU (librknnrt 2.3.2),
  RTC, watchdog, thermals.

Then 2.7 fix-up PRs, 2.8 docs + VERSION 0.2.0 + a release workflow, Ben tags v0.2.0.

## Open unknowns to settle on the board

SCSI index of the user LUN, UFS probe at env load, NOR chip variant, the
reader's logical sector size, module capacity, Linux parse of the 4Kn GPT,
and the hush `for` loop in `nerves_find_disk` (prints errors for missing
devices, expected to be harmless).

# Lenovo Yoga 9i 2-in-1 Gen 11 Aura Edition (14IPH11) on Linux

This project aims to make sound, tablet mode, screen brightness, rotation and wide-gamut P3 colour profile work on this 2-in-1 laptop when running a Linux distro.

All the technical details can be found in [patches](patches/); hopefully they will get merged upstream in future.\
Instructions, scripts and pre-built kernel assume Fedora 44 with Secure Boot turned off

## Auto install for Fedora 44

```bash
curl -fsSL https://raw.githubusercontent.com/laspinacristian/linux-yoga9i-gen11-aura/main/install.sh | sudo bash
```

It installs the patched kernel, the audio topology files, an ALSA configuration and the sensor firmware, then rebuilds the initramfs.
It also sets the screen to its native colour gamut, if you run it from a GNOME session.
Reboot when it finishes. Run it again whenever a new release comes out.

## Build it yourself

The installer uses prebuilt files. To produce them yourself:

- [Kernel](guides/kernel.md) — Fedora's kernel with the four patches added
- [Audio topology](guides/topology.md) — the `.tplg` files, built from SOF
- [Sensor firmware](guides/firmware.md) — extracted from Lenovo's Windows driver

## Other guides

- [Getting the colours right](guides/color.md) — the screen's colour mode, and the login screen
- [Surviving system updates](guides/updates.md) — keeping this kernel the one that boots
- [Undoing the install](guides/uninstall.md) — putting everything back
- [Other distributions](guides/other-distros.md) — if you are not on Fedora
